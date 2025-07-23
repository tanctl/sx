import json
import random

catsounds = ["meow", "mrrp", "purr", "hiss", "nya", "mrow", "mew", "miau", "rrrow"]

def generatejsonlines(filename, count=1000000):
    with open(filename, "w") as f:
        for i in range(count):
            obj = { "id": i, "sound": random.choice(catsounds) }
            f.write(json.dumps(obj) + "\n")

# Usage
generatejsonlines("catsoundslines.json", count=1000000)
