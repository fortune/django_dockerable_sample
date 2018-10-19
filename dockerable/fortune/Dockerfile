FROM python:3.7

WORKDIR /app
COPY . /app
COPY dockerable/fortune/cmd.sh /cmd.sh
RUN chmod a+x /cmd.sh && rm -rf dockerable

RUN pip install -r requirements.txt

CMD ["/cmd.sh"]
