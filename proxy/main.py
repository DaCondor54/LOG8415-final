import pymysql
import sys
import random
from pythonping import ping
from enum import Enum
from dataclasses import dataclass

from fastapi import FastAPI, Body, HTTPException

@dataclass
class ServerCredentials:
    name: str
    password: str

@dataclass
class SQLRequest:
    sql_query: str
    strategy: str

class ForwardingStrategies(Enum):
    DIRECT = 'direct'
    RANDOM = 'random'
    CUSTOM = 'custom'

class InvalidQueryType(Exception):
    pass

class Router:
    source = '54.87.26.74'
    replicas = ['54.167.80.3','54.226.0.76']

    read_queries = {'SELECT'}
    write_queries = {'DELETE', 'INSERT', 'UPDATE'}

    def __init__(self):
        self._forwarding_strategy = ForwardingStrategies.CUSTOM

    def route_query(self, sql_query: str) -> str:
        if self.is_read_query(sql_query):
            return self.select_replica()
        elif self.is_write_query(sql_query):
            return self.source
        else:
            queries = self.read_queries | self.write_queries
            raise InvalidQueryType(f'is not a {queries}')             


    def is_sql_query_of_type(self, sql_query: str, keywords: set[str]) -> bool:
        return any(sql_query.upper().startswith(word) for word in keywords)

    def is_read_query(self, sql_query: str) -> bool:
        return self.is_sql_query_of_type(sql_query, self.read_queries)
    
    def is_write_query(self, sql_query: str) -> bool:
        return self.is_sql_query_of_type(sql_query, self.write_queries)

    def select_replica(self) -> str:
        match self.forwarding_strategy:
            case ForwardingStrategies.DIRECT:
                return self.direct_strategy()
            case ForwardingStrategies.RANDOM:
                return self.random_strategy()
            case ForwardingStrategies.CUSTOM:
                return self.custom_strategy()
            
    def ping_replica(self, replica_ip: str) -> float:
        return ping(target = replica_ip, count = 1).rtt_avg_ms

    def direct_strategy(self) -> str:
        return self.source

    def random_strategy(self) -> str:
        return random.choice(self.replicas)

    def custom_strategy(self) -> str:    
        return min(self.replicas, key=self.ping_replica)
    
    @property
    def forwarding_strategy(self) -> ForwardingStrategies:
        return self._forwarding_strategy
    
    @forwarding_strategy.setter 
    def forwarding_strategy(self, strategy: str):
        if strategy in ForwardingStrategies:
            self._forwarding_strategy = ForwardingStrategies(strategy)
        else:
            self._forwarding_strategy = ForwardingStrategies.CUSTOM


router = Router()
server = ServerCredentials('proxy', 'P@ssword123')

app = FastAPI()

@app.post("/")
async def receive_sql_query(request: SQLRequest):
    try:
        router.forwarding_strategy = request.strategy
        server_ip = router.route_query(request.sql_query)
        return send_sql_query(request.sql_query, server_ip)
    except InvalidQueryType as e:
        print(e)
        raise HTTPException(status_code = 400, detail=str(e))


def send_sql_query(sql_query: str, server_ip: str):    
    cnx = None    
    try:
        cnx = pymysql.connect(
            host=server_ip,
            user=server.name,
            password=server.password,
            database="sakila"
        )

        cursor = cnx.cursor()

        cursor.execute(sql_query)

        rows = cursor.fetchall()
        return { 'rows': rows, 'ip': server_ip, 'is_source': server_ip == router.source, 'strategy': router.forwarding_strategy }

    except pymysql.Error as e:
        print(f"Error connecting to MySQL with PyMySQL: {e}")
        
    finally:        
        if cnx:
            cnx.close()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=3000, reload=True)