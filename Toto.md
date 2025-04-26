To-Do App Documentation Overview The To-Do App is a serverless, microservices-based web application deployed on AWS, designed to allow users to create and view tasks. It leverages AWS free tier services for cost efficiency, uses a static S3 website for the frontend, and a Dockerized Lambda function for the backend, with data stored in an existing PostgreSQL database. The entire infrastructure is provisioned automatically using Terraform. Application Components

Frontend
Description: A static web interface where users can add and view tasks. Implementation: HTML, JavaScript, and Tailwind CSS, hosted on an S3 bucket configured as a static website. Functionality: Displays a list of tasks fetched from the backend. Provides an input field and button to add new tasks. Communicates with the backend via REST API calls.

Backend
Description: A microservices-based API handling task operations. Implementation: A Python-based AWS Lambda function packaged as a Docker image, stored in Amazon ECR. Functionality: Handles GET requests to retrieve all tasks. Handles POST requests to create new tasks. Connects to a PostgreSQL database for data persistence.

Database
Description: Stores task data. Implementation: An existing PostgreSQL server (user-provided, not provisioned by Terraform). Schema: A single tasks table with columns for id, task, and created_at.

API Gateway
Description: Provides a RESTful endpoint for frontend-backend communication. Implementation: AWS API Gateway with a /tasks resource supporting GET and POST methods. Functionality: Routes HTTP requests to the Lambda function and handles CORS.

AWS Services Used and Rationale

Amazon S3
Purpose: Hosts the static frontend (HTML, JavaScript, CSS). Why Used: Cost-Effective: Free tier includes 5GB storage and 20,000 GET requests/month, sufficient for a simple static site. Scalability: Automatically scales to handle traffic. Simplicity: Easy to configure as a static website with public access for global availability.

Configuration: Bucket with public read access, website hosting enabled, and index/error documents set.

AWS Lambda
Purpose: Runs the backend microservice. Why Used: Serverless: No server management, auto-scales based on demand. Free Tier: 1M free requests and 400,000 GB-seconds of compute time/month, ample for low-traffic apps. Docker Support: Allows packaging dependencies (e.g., psycopg2) in a container for consistency.

Configuration: 128MB memory, 30-second timeout, environment variables for PostgreSQL credentials.

Amazon Elastic Container Registry (ECR)
Purpose: Stores the Docker image for the Lambda function. Why Used: Integration: Seamlessly integrates with Lambda for container-based deployments. Free Tier: 500MB storage for private repositories, sufficient for a single microservice image. Security: Provides secure storage for container images.

Configuration: Private repository with Terraform-managed lifecycle policies.

Amazon API Gateway
Purpose: Exposes the Lambda function as a REST API. Why Used: Free Tier: 1M requests/month, suitable for low-traffic applications. Scalability: Handles traffic spikes without manual intervention. Features: Supports CORS, request validation, and easy integration with Lambda.

Configuration: REST API with a single /tasks resource, proxy integration with Lambda.

AWS Identity and Access Management (IAM)
Purpose: Manages permissions for Lambda and API Gateway. Why Used: Security: Ensures least privilege access (e.g., Lambda only has execution and logging permissions). Free: No cost for IAM roles/policies.

Configuration: Role for Lambda with basic execution permissions and API Gateway invoke permissions.

Terraform
Purpose: Automates infrastructure provisioning. Why Used: Automation: Eliminates manual setup, ensuring consistency and repeatability. Infrastructure as Code: Enables versioning, collaboration, and easy updates. Multi-Service Support: Manages S3, Lambda, ECR, API Gateway, and IAM in a single configuration.

Architecture Diagram Below is the architecture diagram in Mermaid syntax, illustrating the flow of data and interactions between components.


Flow Explanation

The user accesses the static website hosted on S3 via a browser. The frontend sends GET/POST requests to API Gateway to fetch or create tasks. API Gateway routes requests to the Lambda function. The Lambda function, running a Dockerized Python app, interacts with the PostgreSQL database to store or retrieve tasks. The Docker image is stored in ECR and deployed to Lambda. Terraform provisions and configures all AWS resources automatically.

Deployment Instructions

Prerequisites:

AWS account with free tier access. Existing PostgreSQL server with credentials. Terraform installed locally. AWS CLI configured with credentials. Docker installed for building the Lambda image.

Setup:

Initialize the PostgreSQL database with the provided init.sql:CREATE TABLE IF NOT EXISTS tasks ( id SERIAL PRIMARY KEY, task VARCHAR(255) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP );

Create a terraform.tfvars file with PostgreSQL credentials:pg_host = "your-pg-host" pg_user = "your-pg-user" pg_password = "your-pg-password" pg_database = "your-pg-database"

Deploy:

Run terraform init to initialize the Terraform workspace. Run terraform plan to review the planned infrastructure. Run terraform apply to provision resources. Build and push the Docker image to ECR using AWS CLI commands (Terraform outputs provide the exact commands). Access the app via the S3 website URL (output by Terraform).

Outputs:

website_url: URL of the S3 static website. api_url: URL of the API Gateway endpoint.

Design Considerations

Cost: All services are within AWS free tier limits (S3: 5GB, Lambda: 1M requests, API Gateway: 1M requests, ECR: 500MB). Scalability: Serverless components (S3, Lambda, API Gateway) auto-scale with demand. Security: IAM roles follow least privilege principles. S3 bucket is public for website hosting but only allows GET operations. PostgreSQL credentials are stored securely as Lambda environment variables.

Maintainability: Terraform enables easy updates and version control of infrastructure. Simplicity: Minimal components (one Lambda, one S3 bucket, one API) reduce complexity.

Limitations

Free Tier Constraints: Exceeding free tier limits (e.g., >1M Lambda requests) incurs costs. PostgreSQL Dependency: Requires an existing PostgreSQL server, not provisioned by Terraform. Basic Functionality: Supports only task creation and listing; advanced features (e.g., task deletion, authentication) are not implemented.

Future Improvements

Add authentication (e.g., using AWS Cognito). Implement task deletion and update operations. Add error handling and input validation in the frontend. Monitor usage with CloudWatch to stay within free tier limits.