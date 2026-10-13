FROM europe-west6-docker.pkg.dev/ahdis-ch/ahdis/matchbox:v4.1.19

COPY ./src/application.yaml /config
COPY ./src/*.tgz /

# Use root to maintain the system
USER root

# Update packages, in case the Matchbox image is too old
RUN apt update && apt upgrade -y

# Remove the package management tools for security reasons
#RUN dpkg -r --force-all apt apt-get && dpkg -r --force-all debconf dpkg

# Switch back to the matchbox user
USER matchbox

EXPOSE 80
RUN java -Xmx3G -Xms1G -jar /matchbox.jar --hapi.fhir.only_install_packages=true
