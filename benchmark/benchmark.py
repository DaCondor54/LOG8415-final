import requests
import sys
import json


ip = sys.argv[1]

STRATEGIES = ['custom', 'direct', 'random']
read_request = 'SELECT * FROM actor LIMIT 1;'
write_request = "INSERT INTO actor(first_name, last_name) VALUES ('john', 'smith');"

def build_request(query: str, strategy: str) -> str:
    return { 'sql_query': query, 'strategy': strategy}

def send_request(sql_query):
    sql_request = json.dumps(build_request(sql_query, strategy))
    response = requests.post(f'http://{ip}:3000', sql_request, headers= {'Authorization': 'Bearer SUPER_SECRET_TOKEN'})
    return response.text

def write_logs(file, strategy, sql_query):
    with open(f'logs/log-{file}-{strategy}.text', 'w') as f:
        responses = [send_request(sql_query) + '\n' for _ in range(10)]
        f.writelines(responses)
        
for strategy in STRATEGIES:
    write_logs('read', strategy, read_request)
    write_logs('read', strategy, write_request)
            
    


