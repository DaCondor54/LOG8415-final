import requests
import sys
import json
import asyncio
import httpx

ip = sys.argv[1]
STRATEGIES = ['custom', 'direct', 'random']
read_request = 'SELECT * FROM actor LIMIT 1;'
write_request = "INSERT INTO actor(first_name, last_name) VALUES ('john', 'smith');"

def build_request(query: str, strategy: str) -> str:
    return { 'sql_query': query, 'strategy': strategy}

async def send_request(sql_query: str, strategy: str, client):
    sql_request = build_request(sql_query, strategy)
    headers = {'Authorization': 'Bearer SUPER_SECRET_TOKEN'}
    response = await client.post(f'http://{ip}:3000', json=sql_request, headers=headers)

    return response.text

async def write_logs(file: str, strategy: str, sql_query: str, client):
    with open(f'logs/log-{file}-{strategy}.text', 'w') as f:
        responses = [send_request(sql_query, strategy, client) for _ in range(1000)]
        results = await asyncio.gather(*responses)
        results = [r + '\n' for r in results]
        f.writelines(results)
        
async def main():
    limits = httpx.Limits(
        max_connections=4000,
        max_keepalive_connections=200
    )
    async with httpx.AsyncClient(timeout=None, limits=limits) as client:
        pending = [write_logs('read', strategy, read_request, client) for strategy in STRATEGIES] + [write_logs('write', 'direct', write_request, client)]
        await asyncio.gather(*pending)
    
    
if __name__ =='__main__':
    asyncio.run(main())

