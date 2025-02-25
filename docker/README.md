# pulsar-release-validation docker image source

This directory is for the scripts for building the pulsar-release-validation docker image.

* Users of the script won't need to build the images. Please check the repository [README](../README.md) for using the validation script.
* You can find a prebuilt image in docker hub, [`lhotari/pulsar-release-validation`](https://hub.docker.com/r/lhotari/pulsar-release-validation/tags). 
  * The [validate_pulsar_release_in_docker.sh](../scripts/validate_pulsar_release_in_docker.sh) and [validate_pulsar_release_in_docker.ps1](../scripts/validate_pulsar_release_in_docker.ps1) scripts will automatically download the image from docker hub.
