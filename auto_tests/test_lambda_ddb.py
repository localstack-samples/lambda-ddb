import pytest
import requests
import simplejson as json

from utils import DotDict_utils
from utils.fixtures import iac_output
from utils import get_logger

logger = get_logger.logger()


@pytest.mark.integration
class TestNameApigw:
    @staticmethod
    def get_env_vars(iac_output):
        return DotDict_utils.DotDict(
            {
                "REST_API_ENDPOINT": iac_output["apigwUrl"],
            }
        )

    def test_lambda_ddb_integration(self, iac_output):
        env = TestNameApigw.get_env_vars(iac_output)
        base_url = env.REST_API_ENDPOINT.replace("https", "http")
        url = f"{base_url}?name=localstack"
        logger.info(f"url: {json.dumps(url)}")
        response = requests.get(
            url)
        print("#######################")
        logger.info(f"response: {response.text}")
        assert response.status_code == 200
        result = json.loads(response.text)
        assert 'body' in result
        body = result['body']
        assert 'name' in body
        name_obj = body['name']
        assert 'submittedName' in name_obj
        submitted_name = name_obj['submittedName']
        assert submitted_name == "localstack"
