FROM loadimpact/k6:latest
COPY k6-loadtest.js /loadtest/k6-loadtest.js
WORKDIR /loadtest
ENTRYPOINT ["k6"]
CMD ["run", "/loadtest/k6-loadtest.js"]
