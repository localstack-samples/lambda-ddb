import * as cdk from 'aws-cdk-lib'
import {aws_s3 as s3, Duration, RemovalPolicy} from 'aws-cdk-lib'
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb'
import {Architecture, AssetCode, Code, Function, Runtime, LayerVersion} from "aws-cdk-lib/aws-lambda"
import {Construct} from 'constructs'
import * as Iam from "aws-cdk-lib/aws-iam"
import {PolicyStatement} from "aws-cdk-lib/aws-iam"
import * as S3 from "aws-cdk-lib/aws-s3"
// API Gateway V2 HTTP API - ALPHA
import {HttpLambdaIntegration} from 'aws-cdk-lib/aws-apigatewayv2-integrations'
import * as apigwv2 from "aws-cdk-lib/aws-apigatewayv2"
import {HttpApi} from "aws-cdk-lib/aws-apigatewayv2"

export interface LsMultiEnvAppProps extends cdk.StackProps {
    isLocal: boolean;
    environment: string;
    handler: string;
    runtime: Runtime;
    lambdaDistPath: string;
    listBucketName: string;
    stageName: string;
    version: string;
    region: string;
}

// AWS CDK App Stack
// Create an S3 bucket, Lambda, HttpAPI with Lambda binding
export class AwscdkStack extends cdk.Stack {
    private httpApi: HttpApi
    private lambdaFunction: Function
    private bucket: s3.Bucket
    private lambdaCode: Code

    constructor(scope: Construct, id: string, props: LsMultiEnvAppProps) {
        super(scope, id, props)

        // Run Lambda on ARM_64 in AWS and locally when local arch is ARM_64.
        let arch = Architecture.ARM_64
        const localArch = process.env.LOCAL_ARCH
        if (props.isLocal && localArch == 'x86_64') {
            arch = Architecture.X86_64
        }
        // Lambda Source Code
        // If running on LocalStack, setup Hot Reloading with a fake bucked named hot-reload
        if (props.isLocal) {
            const lambdaBucket = s3.Bucket.fromBucketName(this, "HotReloadingBucket", "hot-reload")
            this.lambdaCode = Code.fromBucket(lambdaBucket, props.lambdaDistPath)
        } else {
            this.lambdaCode = new AssetCode(`../../src/lambda-hello-name/lambda.zip`)
        }

        // create a table
        const ddbTable = new dynamodb.Table(this, `mytable-${props.environment}`, {
            tableName: `mytable-${props.environment}`,
            partitionKey: {
                name: 'id',
                type: dynamodb.AttributeType.STRING,
            },
        })

        // Create a bucket for some future purpose
        this.bucket = new s3.Bucket(this, 'lambdawork', {
            enforceSSL: false,
            removalPolicy: RemovalPolicy.DESTROY,
        })

        // HTTP API Gateway V2
        this.httpApi = new HttpApi(this, this.stackName + "HttpApi", {
            description: "AWS CDKv2 HttpAPI-alpha"
        })

        // Allow Lambda to list bucket contents
        const lambdaPolicy = new PolicyStatement()
        lambdaPolicy.addActions("s3:ListBucket")
        lambdaPolicy.addResources(this.bucket.bucketArn)

        // Create the Lambda
        this.lambdaFunction = new Function(this, 'name-lambda', {
            functionName: 'name-lambda',
            architecture: arch,
            handler: props.handler,
            runtime: props.runtime,
            code: this.lambdaCode,
            memorySize: 512,
            timeout: Duration.seconds(10),
            environment: {
                BUCKET: this.bucket.bucketName,
                DDB_TABLE_NAME: ddbTable.tableName,
            },
            layers: [],
            initialPolicy: [lambdaPolicy],
        })
        // Allow Lambda to write to this DDB table
        ddbTable.grantWriteData(this.lambdaFunction)


        // HttpAPI Lambda Integration for the above Lambda
        const nameIntegration =
            new HttpLambdaIntegration('NameIntegration', this.lambdaFunction)

        // HttpAPI Route
        // Method:      GET
        // Path:        /
        // Integration: Lambda
        this.httpApi.addRoutes({
            path: '/',
            methods: [apigwv2.HttpMethod.GET],
            integration: nameIntegration,
        })

        // Output the DDB Table Name
        new cdk.CfnOutput(this, 'ddbTableName', {
            value: ddbTable.tableName,
            exportName: 'ddbTableName',
        })
        // Output the HttpApiEndpoint
        new cdk.CfnOutput(this, 'HttpApiEndpoint', {
            value: this.httpApi.apiEndpoint,
            exportName: 'HttpApiEndpoint',
        })
    }

}

