FROM ubuntu:latest

COPY _build/default/rel/registry /work/registry/

WORKDIR /work/registry

ENTRYPOINT ["bin/registry"]

CMD ["foreground"]

#COPY set_args.sh /work/registry/

# RUN chmod +x /work/registry/set_args.sh 

#ENTRYPOINT ["./set_args.sh"]

# -------------------------------------------------------------------------
#For reference
# FROM ubuntu:latest
# RUN apt-get update && apt-get install -y libexpat1
# COPY _build/default/rel/api /work/api/
# WORKDIR /work/api
# COPY set_args.sh /work/api/
# COPY libcrypto.so.1.1  /work/api/
# RUN chmod +x /work/api/set_args.sh
# CMD ["/bin/bash", "./set_args.sh"]
