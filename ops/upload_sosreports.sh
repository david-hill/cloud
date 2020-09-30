
if [ -z $1 ]; then
  echo "Please provide a case number..."
  exit 1
fi

for p in sosreport-*; do
  redhat-support-tool addattachment -c $1 $p
done
