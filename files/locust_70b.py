from locust import HttpUser, TaskSet, task, constant_throughput, LoadTestShape
import logging as log
import random

model = "meta/llama-3.1-70b-instruct"

prompt_payloads = [
    {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a helpful scientific research assistant."},
            {"role": "user", "content": "Summarize the latest research in CRISPR gene editing from the past year with citations."}
        ],
        "max_tokens": 8000,
        "temperature": 0.5,
        "top_p": 0.9,
        "stream": False
    },
    {
        "model": model,
        "messages": [
            {"role": "user", "content": "You're an AI assistant helping a developer build a Python web scraper. Show the code, explain it, and provide best practices."}
        ],
        "max_tokens": 5000,
        "top_p": 0.98,
        "stream": False
    },
    {
        "model": model,
        "messages": [
            {"role": "user", "content": "I have this SQL query that's timing out: SELECT * FROM orders JOIN customers ON orders.customer_id = customers.id WHERE orders.date > '2023-01-01'"}
        ],
        "max_tokens": 4200,
        "temperature": 0.45,
        "top_p": 0.9,
        "stream": False
    },
    {
        "model": model,
        "messages": [
            {"role": "system", "content": "Compare Rust and Go for building a microservices backend. Cover performance, developer ergonomics, ecosystem, and concurrency model."}
        ],
        "max_tokens": 7000,
        "temperature": 0.4,
        "top_p": 0.92,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "How do Kubernetes Services find Pods?"}],
        "max_tokens": 8000,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Explain how the solar system was formed in the early universe?"}],
        "max_tokens": 7048,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "How are python metaclasses different from baseclasses? Explain with examples."}],
        "max_tokens": 8096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Explain the complete steps how I can file my US taxes on the form 1040. Provide example for each line."}],
        "max_tokens": 8096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Prove Pythagoras Theorem 3 different ways."}],
        "max_tokens": 5048,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Describe the events leading up to world war one."}],
        "max_tokens": 8096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Describe the events leading up to world war two."}],
        "max_tokens": 6096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "How can we calculate the entropy of two dimensional and three dimensional geometric shapes?"}],
        "max_tokens": 6096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Write a 1000 word story of Star Wars in the style of a Bollywood movie."}],
        "max_tokens": 6096,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Write a 1000 word story of Rene Descartes in the lines of a Hollywood movie."}],
        "max_tokens": 6096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Just make a plausible way of building a passenger airplane using steam engines. What are the design issues we may have to solve and propose some possible solutions."}],
        "max_tokens": 7096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Provide a month long fitness plan to reduce my weight by 10 kgs and at the same time help me build muscle. Provide a daily meal plan and recipes."}],
        "max_tokens": 7096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "How can we scale inference pods for LLM workloads using kubernetes. Provide steps and example kubernetes deployments files and commands."}],
        "max_tokens": 8048,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "Write a 1000 word story of a boy meeting girl and developing friendship over 2 years and finally breaking apart. When you describe the story make sure to reverse every word of the story."}],
        "max_tokens": 4096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    },
    {
        "model": model,
        "messages": [{"role": "user", "content": "You are an english professor teaching the evolution of the language over the centuries. Write Chapter 1 of the book with different sections. Each section should be atleast 500 words."}],
        "max_tokens": 3096,
        "temperature": 0.4,
        "top_p": 0.88,
        "stream": False
    }
]

class UserTasks(TaskSet):
    @task
    def get_site(self):
        headers = {"Content-Type": "application/json", "Connection": "close"}
        with self.client.post("/v1/chat/completions", headers=headers, json=random.choice(prompt_payloads)) as response:
            _ = response.content

class User(HttpUser):
    tasks = [UserTasks]
    wait_time = constant_throughput(1)
    connection_timeout = 300.0
    network_timeout = 300.0
    host = "http://meta-llama3-70b-instruct.nim.svc.cluster.local:8000"

from locust import LoadTestShape
from math import exp

class CustomShape(LoadTestShape):
    # Define growth and decay steps
    # growth_steps = [
    #     {"amplitude": 120, "rate": 20, "offset": 0},
    #     {"amplitude": 210, "rate": 20, "offset": 3},
    #     {"amplitude": 200, "rate": 20, "offset": 6},
    #     {"amplitude": 320, "rate": 20, "offset": 12},
    # ]

    # decay_steps = [
    #     {"amplitude": 320, "rate": 20, "offset": 18},
    #     {"amplitude": 200, "rate": 20, "offset": 24},
    #     {"amplitude": 210, "rate": 20, "offset": 27},
    #     {"amplitude": 120, "rate": 20, "offset": 30},
    # ]

    growth_steps = [
        {"amplitude": 300, "rate": 20, "offset": 0},
        {"amplitude": 525, "rate": 20, "offset": 3},
        {"amplitude": 500, "rate": 20, "offset": 6},
        {"amplitude": 800, "rate": 20, "offset": 12},
    ]
    decay_steps = [
        {"amplitude": 800, "rate": 20, "offset": 18},
        {"amplitude": 500, "rate": 20, "offset": 24},
        {"amplitude": 525, "rate": 20, "offset": 27},
        {"amplitude": 300, "rate": 20, "offset": 30},
    ]

    def safe_exp(self, x):
        """Clamp input to avoid OverflowError."""
        if x > 700:
            return exp(700)
        elif x < -700:
            return exp(-700)
        return exp(x)

    def tick(self):
        run_time = self.get_run_time()
        t = (run_time / 60.0) % 30  # Normalize time and repeat every 30 minutes

        growth_sum = sum(
            step["amplitude"] / (1 + self.safe_exp(-step["rate"] * (t - step["offset"])))
            for step in self.growth_steps
        )

        decay_sum = sum(
            step["amplitude"] / (1 + self.safe_exp(-step["rate"] * (t - step["offset"])))
            for step in self.decay_steps
        )

        user_num = int(growth_sum - decay_sum)
        print("values:", growth_sum, decay_sum, user_num)
        return (max(0, user_num), 20)

class CustomShapeold(LoadTestShape):
    def tick(self):
        from math import sin, cos
        run_time = self.get_run_time()
        current_user = run_time // 120
        user_num = int(120 + 15 * (cos(4 * current_user / 6) + 7 * sin(4 * current_user / 30)))
        return (max(0, user_num), 10)
