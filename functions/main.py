import json
import urllib
import google.auth.transport.requests
import google.oauth2.id_token
from datetime import datetime, timedelta

def export_function(request):
    request = request.get_data()

    try: 
        request_json = json.loads(request.decode())

    except ValueError as e:
        print(f"Error decoding JSON: {e}")
        return "JSON Error", 400
    
    apigee_organization = request_json.get("apigee_organization")
    apigee_env = request_json.get("apigee_env")
    apigee_datastore_name = request_json.get("apigee_datastore_name")
    
    # Validate if start and end are set
    if "start" in request_json and "end" in request_json:
        start   = request_json["start"]
        end     = request_json["end"]
    
    # Current day and day before
    else:
        start = datetime.today() - timedelta(days=1)
        start = start.strftime('%Y-%m-%d')
        end = datetime.today().strftime('%Y-%m-%d')

    url = "https://apigee.googleapis.com/v1/organizations/%s/environments/%s/analytics/exports".format(apigee_organization, apigee_env, apigee_datastore_name)
    
    auth_req = google.auth.transport.requests.Request()
    id_token = google.oauth2.id_token.fetch_id_token(auth_req, url)

    data = {
        "name": "world",
        "description": "world",
        "dateRange": {
            "start":start,
            "end":end
        },
        "outputFormat":"csv",
        "csvDelimiter": ",", 
        "datastoreName": apigee_datastore_name
    }
    data = json.dumps(data)
    data = data.encode()

    req = urllib.request.Request(url, data=data)
    req.add_header("Authorization", f"Bearer {id_token}")
    response = urllib.request.urlopen(req)

    return response.read()