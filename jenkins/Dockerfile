# jenkins/Dockerfile
#
# Custom Jenkins image with all tools required to run the stock-predictor pipeline:
#   - Jenkins LTS
#   - JDK 21 (matches pom.xml java.version=21)
#   - Maven 3.9
#   - Docker CLI (talks to the host Docker socket via volume mount)
#   - curl and git
#
# All required plugins are installed via plugins.txt at image build time,
# so Jenkins starts ready to use without manual plugin installation.

FROM jenkins/jenkins:lts-jdk21

# Switch to root to install system packages
USER root

# ── Install Docker CLI ────────────────────────────────────────────────────────
# Jenkins needs the Docker CLI to run `docker build` and `docker run` inside
# pipeline stages. The actual Docker daemon runs on the host and is accessed
# via the mounted /var/run/docker.sock socket.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
       https://download.docker.com/linux/debian \
       $(lsb_release -cs) stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ── Install Maven 3.9 ─────────────────────────────────────────────────────────
ENV MAVEN_VERSION=3.9.9
ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

RUN curl -fsSL \
    "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    | tar -xzf - -C /opt \
    && ln -s "/opt/apache-maven-${MAVEN_VERSION}" "${MAVEN_HOME}"

# ── Add jenkins user to docker group ─────────────────────────────────────────
# The docker group on the host typically has GID 999 or 1000.
# We create a group with the same GID so the jenkins user can write to the socket.
# The GID is overridable at runtime via the DOCKER_GID build arg.
ARG DOCKER_GID=999
RUN groupadd -g ${DOCKER_GID} docker-host 2>/dev/null || true \
    && usermod -aG docker-host jenkins \
    && usermod -aG docker jenkins 2>/dev/null || true

# ── Skip the Jenkins setup wizard ────────────────────────────────────────────
# All plugins are pre-installed. The initial admin password is still generated
# but the wizard steps are bypassed.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# ── Pre-install all required plugins ─────────────────────────────────────────
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# ── Drop back to jenkins user ─────────────────────────────────────────────────
USER jenkins
