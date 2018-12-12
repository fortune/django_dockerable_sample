FROM python:3.7

WORKDIR /app

# まず requirements.txt を pip install する方が、全体をコピーしてから pip install するよりも効率がよいのだそうだ。
#
# https://www.aptible.com/documentation/enclave/tutorials/faq/dockerfile-caching/pip-dockerfile-caching.html
#
COPY requirements.txt /app/
RUN pip install -r requirements.txt

COPY . /app
COPY dockerable/cmd.sh /cmd.sh
RUN chmod a+x /cmd.sh && rm -rf dockerable

CMD ["/cmd.sh"]
