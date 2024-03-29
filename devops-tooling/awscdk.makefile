awscdkinstall:
	cd $(STACK_DIR) && npm install
#	cd $(STACK_DIR) && $(CDK_CMD) get
awscdkbootstrap: iac-shared awscdkinstall build
	cd $(STACK_DIR) && $(CDK_CMD) bootstrap
awscdkdeploy: iac-shared
	cd $(STACK_DIR) && $(CDK_CMD) deploy $(TFSTACK_NAME) --outputs-file stack-outputs-$(STACK_SUFFIX).json
awscdkdestroy: iac-shared
	cd $(STACK_DIR) && $(CDK_CMD) destroy $(TFSTACK_NAME)

awscdkoutput:
	jq '{ apigwUrl: ."LambdaDDB-$(STACK_SUFFIX)".HttpApiEndpoint, ddbTableName: ."LambdaDDB-$(STACK_SUFFIX)".ddbTableName }' \
	iac/awscdk/stack-outputs-$(STACK_SUFFIX).json


# LocalStack target groups
#local-awscdk-install: awscdkinstall
# VPC
local-awscdk-vpc-deploy: build awscdkdeploy
local-awscdk-vpc-destroy: awscdkdestroy
# Lambda - DDB
local-awscdk-bootstrap: awscdkbootstrap
local-awscdk-deploy: build awscdkdeploy
local-awscdk-destroy: awscdkdestroy
local-awscdk-output: awscdkoutput

# Lambda - DDB
integ-awscdk-bootstrap: awscdkbootstrap
integ-awscdk-deploy: build awscdkdeploy
integ-awscdk-destroy: awscdkdestroy
integ-awscdk-output: awscdkoutput

local-awscdk-test:
	make -s local-awscdk-output > auto_tests/iac-output.json;
	make -s test

local-awscdk-invoke:
	@APIGW=$$(make local-awscdk-output | jq -r '.apigwUrl') && \
	curl "http://$${APIGW}";

local-awscdk-invoke-loop:
	@APIGW=$$(make local-awscdk-output | jq -r '.apigwUrl') && \
	sh run-lambdas.sh "http://$${APIGW}"

integ-awscdk-test:
	make -s integ-awscdk-output > auto_tests/iac-output.json;
	make -s test

integ-awscdk-invoke:
	@APIGW=$$(make integ-awscdk-output | jq -r '.apigwUrl') && \
	curl "http://$${APIGW}";

integ-awscdk-invoke-loop:
	@APIGW=$$(make integ-awscdk-output | jq -r '.apigwUrl') && \
	sh run-lambdas.sh "http://$${APIGW}"

local-awscdk-clean:
	- rm -rf iac/awscdk/cdk.out

# AWS Sandbox target groups
# VPC
sbx-awscdk-vpc-deploy: build awscdkdeploy
sbx-awscdk-vpc-destroy: awscdkdestroy
# Lambda - APIGW - S3
sbx-awscdk-bootstrap: awscdkbootstrap
sbx-awscdk-deploy: build awscdkdeploy
sbx-awscdk-destroy: awscdkdestroy
sbx-awscdk-output: awscdkoutput

sbx-awscdk-invoke:
	@APIGW=$$(aws cloudformation describe-stacks \
  --stack-name LsMultiEnvApp-sbx \
  --query "Stacks[0].Outputs[?ExportName=='HttpApiEndpoint'].OutputValue" \
  --output text) && \
	curl "$${APIGW}";
	@rm -f awscdk-output.json
