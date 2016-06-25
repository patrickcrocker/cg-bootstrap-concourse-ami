# Concourse Packer

A packer template and associated resources for creating an AMI that runs a standalone Concourse installation suitable for bootstrapping more complex infrastructure.

### Setup

To build an AMI with this template first create a secrets.json file with the following contents:

```
{
	"aws_access_key": "your-aws-access-key",
	"aws_secret_key": "your-aws-secret-key",
	"aws_region": "us-gov-west-1"
}
```

If deploying to a region other than `us-gov-west-1` add the the `source_ami` key to the secrets
with the appropriate AMI-ID for the region. According to the [Concourse installation guide](https://concourse.ci/binaries.html) only Ubuntu 14.04 LTS is supported.

AMI-IDs for other regions can be found by using [Ubuntu's AMI locator](https://cloud-images.ubuntu.com/locator/ec2/) and selecting the `14.04 LTS hvm:ebs-ssd` image for the desired region.

### Building

Once a secrets file has been created created, the AMI can be built with the following command:

```
packer build -var-file=secrets.json bootstrap_concourse.json
```

Once the process finishes a new AMI will be ready for use in the selected region.

### Using

#### Setting credentials

The AMI created by this template supports setting the concourse basic-auth username and password via [user-data](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) when the instance is boooted.

This is done by providing a simple YAML document that contains `username` and `password` keys as the instance's user-data. The `hostname` key is optional, but if set will be passed as `external-url` to concourse.  If `hostname` is not provided, then the `public-hostname` from the metadata service will be used

```
# This is a sample YAML file that will configure the concourse username and password

username: admin
password: swordfish
hostname: ci.example.com
```

#### Accessing Concourse
Concourse runs on `port 80`. Ensure the instance is placed into a security group that allows access to this port.
