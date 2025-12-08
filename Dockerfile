FROM python:3.11-alpine

RUN addgroup -g 65522 buildpiper && \
    adduser -u 65522 -G buildpiper -D -h /home/buildpiper buildpiper && \
    mkdir -p \
      /app \
      /bp/data \
      /bp/execution_dir \
      /bp/workspace \
      /opt/buildpiper/shell-functions \
      /opt/buildpiper/data \
      /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /app /bp /opt /home/buildpiper

RUN apk --no-cache add bash jq curl git gettext libintl tar gzip

# Install kube-linter
RUN wget https://github.com/stackrox/kube-linter/releases/download/v0.7.6/kube-linter-linux.tar.gz && \
    tar -xvf kube-linter-linux.tar.gz && \
    mv kube-linter /usr/local/bin/ && \
    rm -rf kube-linter-linux.tar.gz

WORKDIR /app

COPY --chown=buildpiper:buildpiper build.sh .
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/ /opt/buildpiper/shell-functions/
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS/data /opt/buildpiper/data

RUN chmod +x /app/build.sh && \
    chown -R buildpiper:buildpiper /app /opt /bp

ENV PATH="/usr/local/bin:$PATH" \
    PYTHONUNBUFFERED=1

USER buildpiper

ENTRYPOINT ["./build.sh"]
