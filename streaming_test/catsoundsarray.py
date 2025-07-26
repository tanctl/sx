import json
import random

catsounds = ["meow", "mrrp", "purr", "hiss", "nya", "mrow", "mew", "miau", "rrrow"]

def generatearrayjson(filename, count=1000000):
    with open(filename, "w") as f:
        f.write("[\n")
        for i in range(count):
            obj = { "id": i, "sound": random.choice(catsounds) }
            f.write(json.dumps(obj))
            if i < count - 1:
                f.write(",\n")
        f.write("\n]")

# Usage
generatearrayjson("catsoundsarray.json", count=1000000)
