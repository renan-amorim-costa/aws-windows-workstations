# Jenkins with Terraform and the AWS CLI built in. Build tools belong in the
# image: anything installed inside a running container is lost on rebuild.

FROM jenkins/jenkins:lts-jdk21

USER root

ARG TERRAFORM_VERSION=1.15.8

RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl ca-certificates \
 && curl -fsSL -o /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
 && unzip -q /tmp/terraform.zip -d /usr/local/bin \
 && chmod +x /usr/local/bin/terraform \
 && curl -fsSL -o /tmp/awscli.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
 && unzip -q /tmp/awscli.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/terraform.zip /tmp/awscli.zip /tmp/aws \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# The repository is mounted from the host and owned by another user inside the
# container; without this git refuses it as "dubious ownership". System scope
# (/etc/gitconfig), because the jenkins user's global config lives in the
# jenkins_home volume, which hides anything written there at build time.
# Two entries: the clone opens /repo/.git as a path of its own.
RUN git config --system --add safe.directory /repo \
 && git config --system --add safe.directory /repo/.git

USER jenkins

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# No setup wizard: the configuration comes from casc.yaml.
# ALLOW_LOCAL_CHECKOUT lets the job clone the mounted repository (file:///repo).
# Fine for a single-user Jenkins on your own machine; a shared Jenkins should
# clone from a remote repository instead.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true"
ENV CASC_JENKINS_CONFIG=/var/jenkins_conf/casc.yaml
