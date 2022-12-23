import json
import os


def main():
    conf = os.path.expanduser('~/.docker/config.json')
    with open(conf, 'r') as f:
        data = json.load(f)
    data.setdefault('credHelpers', {})
    helpers = data['credHelpers']
    helpers.setdefault('public.ecr.aws', 'ecr-login')
    helpers.setdefault('804927176937.dkr.ecr.us-east-2.amazonaws.com', 'ecr-login')
    st = json.dumps(data, indent=4)
    with open(conf, 'w') as f:
        json.dump(data, f, indent=4)


if __name__ == "__main__":
    main()
