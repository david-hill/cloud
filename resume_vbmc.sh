vbmc list | grep rhosp | awk '{ print $6 }' | xargs -I{} ip a add {}/32 dev virbr0
vbmc list | grep rhosp | awk '{ print $2 }' | xargs -I{} vbmc start {}

