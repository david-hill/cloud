# make sure ~/containers-prepare-parameter.yaml contains  push_destination: false

sudo openstack tripleo container image prepare   -e ~/containers-prepare-parameter.yaml > overcloud_images.yaml

username="your_username"
password="your_password"
while read -r line; do 
	image=$(echo $line | awk '{ print $2 }') 
	echo $image
       	skopeo inspect --creds $username:$password docker://$image | jq .RepoTags
done < overcloud_images.yaml
