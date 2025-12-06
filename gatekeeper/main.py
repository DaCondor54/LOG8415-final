from dataclasses import dataclass, asdict
import requests
import json

from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

@dataclass
class SQLRequest:
    sql_query: str
    strategy: str

class DangerousQueryException(Exception):
    pass

security = HTTPBearer()

trusted_host = 'proxy.internal'
dangerous_queries = {'DROP DATABASE', 'DELETE ALL', 'TRUNCATE', 'DELETE FROM'}
SUPER_SECRET_TOKEN = 'SUPER_SECRET_TOKEN'

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.scheme.lower() != 'bearer':
        raise HTTPException(status_code=401, detail="Invalid authentication scheme")
    
    if credentials.credentials != SUPER_SECRET_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    return {"authenticated": True, "token": credentials.credentials}

def validate_query_safety(sql_query: str) -> bool:
    for dangerous_query in dangerous_queries:
        if sql_query.startswith(dangerous_query):
            raise DangerousQueryException(f'SQL is unsafe because it contains : {dangerous_query}')

def send_sql_query(request):
    json_request = json.dumps(asdict(request), indent=4)
    response = requests.post(f"http://{trusted_host}:3000", json_request)
    return response.json()

app = FastAPI()

@app.post("/")
async def receive_sql_query(request: SQLRequest, auth: dict = Depends(verify_token)):
    try:
        validate_query_safety(request.sql_query)
        return send_sql_query(request)
    except DangerousQueryException as e:
        print(e)
        raise HTTPException(status_code = 400, detail=str(e))
    except ValueError as e:
        print(e)
        raise HTTPException(status_code = 400, detail="Response content is not valid JSON. : " + str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=3000, reload=True)