from locust import HttpUser, TaskSet, task, constant_throughput, LoadTestShape
import logging as log
import random

model = "meta/llama-3.1-8b-instruct"
prompt = [
   {"inputs": "What is Deep Learning?", "parameters":{"max_new_tokens": 5000}},
   {"inputs": "Write a short story about a cat who learns to fly.", "parameters":{"max_new_tokens": 2000}},
   {"inputs": "Describe the most beautiful sunset you've ever seen.", "parameters":{"max_new_tokens": 7000}},
   {"inputs": "Tell me a joke about a dog.", "parameters":{"max_new_tokens": 2000}},
   {"inputs": "Write a short script for a comedy sketch about a group of friends trying to plan a road trip.", "parameters":{"max_new_tokens": 7000}},
   {"inputs": "Describe the most memorable birthday you've ever had.", "parameters":{"max_new_tokens": 6500}},
   {"inputs": "Write a short story about a person who discovers a hidden talent for painting.", "parameters":{"max_new_tokens": 6500}},
   {"inputs": "Tell me a story about a time when you overcame a difficult challenge.", "parameters":{"max_new_tokens": 8000}},
   {"inputs": "Write a poem about the power of love.", "parameters":{"max_new_tokens": 7000}},
   {"inputs": "Describe the most delicious meal you've ever had.", "parameters":{"max_new_tokens": 7200}},
   {"inputs": "Write a short script for a drama about a family dealing with the loss of a loved one.", "parameters":{"max_new_tokens": 7500}},
   {"inputs": "Tell me a joke about a cat.", "parameters":{"max_new_tokens": 2000}},
   {"inputs": "Write a short script for a comedy sketch about a group of coworkers trying to plan a surprise party for their boss.", "parameters":{"max_new_tokens": 5500}}]

class UserTasks(TaskSet):
    @task
    def get_site(self):
        headers = {"Content-Type":"application/json", "Connection":"close"}
        with self.client.post("/v1/chat/completions", headers=headers, json=random.choice(prompt)) as response:
            _ = response.content

class User(HttpUser):
    tasks = {UserTasks}
    wait_time = constant_throughput(1)
    connection_timeout = 300.0
    network_timeout = 300.0

class CustomShape(LoadTestShape):
    def tick(self):
        from math import sin, cos
        run_time = self.get_run_time()
        current_user = run_time // 120
        user_num = int(120 +  15 *(cos(4 * current_user / 6) + (7 * sin(4 * current_user / 30))))
        return (max(0,user_num), 10) 