FROM 309908671491.dkr.ecr.us-east-1.amazonaws.com/ruby:2.7.5-3.7.4 AS dev
ENV WORKDIR=/rtr
WORKDIR ${WORKDIR}
COPY . ${WORKDIR}/
RUN bundle install
