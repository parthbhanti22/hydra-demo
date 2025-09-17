cat > random_hits.sh <<'EOF'
#!/usr/bin/env bash
TARGET="http://localhost:8080"
N=${1:-200}
for i in $(seq 1 $N); do
  host="test$(shuf -i 1-9999 -n1).example"
  if [ $((RANDOM%10)) -eq 0 ]; then
    # 10% chance to block a random host
    curl -s -X POST -d "url=${host}" "$TARGET/block" >/dev/null &
  else
    # otherwise check
    curl -s "$TARGET/check?url=${host}" >/dev/null &
  fi
  sleep 0.05
done
wait
echo "Sent $N random hits"
EOF

chmod +x random_hits.sh
# run 200 random hits
./random_hits.sh 200
