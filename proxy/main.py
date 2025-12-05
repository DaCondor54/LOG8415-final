import pymysql
import sys
import random
from pythonping import ping
from enum import Enum
from dataclasses import dataclass

from fastapi import FastAPI, Body

@dataclass
class Server:
    name: str
    ip: str
    password: str

class ForwardingStrategies(Enum):
    DIRECT = 'direct'
    RANDOM = 'random'
    CUSTOM = 'custom'

class Router:
    source = Server('source', '1.1.1.1', 'P@ssword123')
    replicas = [Server('replica_1', '1.1.1.1', 'Replic@1'), Server('replica_2', '1.1.1.1', 'Replic@2')]

    read_queries = {'SELECT'}
    write_queries = {'DELETE', 'INSERT'}

    def __init__(self, forwarding_strategy: ForwardingStrategies):
        self.forwarding_strategy = forwarding_strategy

    def route_query(self, sql_query: str) -> Server:
        return self.select_replica() if self.is_read_query(sql_query) else self.source    

    def is_read_query(self, sql_query: str) -> bool:
        return any(sql_query.upper().startswith(word) for word in self.read_queries)

    def select_replica(self) -> str:
        match self.forwarding_strategy:
            case ForwardingStrategies.DIRECT:
                return self.direct_strategy()
            case ForwardingStrategies.RANDOM:
                return self.random_strategy()
            case ForwardingStrategies.CUSTOM:
                return self.custom_strategy()
            
    def ping_replica(self, replica: Server):
        return ping(target = replica.ip, count = 1).rtt_avg_ms

    def direct_strategy(self) -> str:
        return self.source

    def random_strategy(self) -> str:
        return random.choice(self.replicas)

    def custom_strategy(self) -> str:    
        return min(self.replicas, key=self.ping_replica)

forwarding_strategy = ForwardingStrategies(sys.argv[1]) if sys.argv[1] in ForwardingStrategies else ForwardingStrategies.CUSTOM
router = Router(forwarding_strategy)

app = FastAPI()

@app.post("/")
async def receive_sql_query(sql_query: str = Body(...)):

    server = router.route_query(sql_query)
    return send_sql_query(sql_query, server)

def send_sql_query(sql_query: str, server: Server):
    if sql_query != None:
        return server
    
    cnx = None    
    try:
        cnx = pymysql.connect(
            host=server.ip,
            user=server.name,
            password=server.password,
            database="sakila"
        )

        cursor = cnx.cursor()

        cursor.execute(sql_query)

        rows = cursor.fetchall()
        for row in rows:
            print(row)

    except pymysql.Error as e:
        print(f"Error connecting to MySQL with PyMySQL: {e}")
        
    finally:        
        if cnx:
            cnx.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=3000, reload=True)