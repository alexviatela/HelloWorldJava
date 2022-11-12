#!/bin/sh
echo "Inicia Proceso"

echo "1 Inicio -  Eliminación y Creación de Llaves"
aws ec2 delete-key-pair --key-name AlexKeyPair
rm AlexKeyPair.pem
aws ec2 create-key-pair --key-name AlexKeyPair --query 'KeyMaterial' --output text > AlexKeyPair.pem
chmod 600 AlexKeyPair.pem
echo "1 Fin - Llaves Creadas"

echo "2 Inicio - Creación de VPC"
id_VPC=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text)
echo "2 Fin - Creación de VPC $id_VPC"


echo "3 Inicio - Creación de Subnet, GateWay, RouteTable"
aws ec2 create-subnet --vpc-id $id_VPC --cidr-block 10.0.1.0/24 --output text

id_Gateway=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --vpc-id $id_VPC --internet-gateway-id $id_Gateway

id_Route_Table=$(aws ec2 create-route-table --vpc-id "$id_VPC" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id $id_Route_Table --destination-cidr-block 0.0.0.0/0 --gateway-id $id_Gateway
aws ec2 describe-route-tables --route-table-id $id_Route_Table --output text

id_Subnet=$(aws ec2 describe-subnets --filters "Name=vpc-id","Values='$id_VPC'" --query "Subnets[0].{ID:SubnetId}" --output text)
aws ec2 associate-route-table  --subnet-id $id_Subnet --route-table-id $id_Route_Table
aws ec2 modify-subnet-attribute --subnet-id $id_Subnet --map-public-ip-on-launch

echo "3 Fin - Creación de Subnet($id_Subnet), GateWay($id_Gateway), RouteTable($id_Route_Table)"


echo "4 Inicio - Creación de SecurityGroups"
aws ec2 create-security-group --group-name my-sg-cli --description "Test Security Group" --vpc-id $id_VPC

aws ec2 describe-security-groups --filters Name=group-name,Values=my-sg-cli --query "SecurityGroups[*].{ID:GroupId}" --output text

id_sec_group=$(aws ec2 describe-security-groups --filters Name=group-name,Values=*my-sg-cli* --query "SecurityGroups[*].{ID:GroupId}" --output text)

aws ec2 authorize-security-group-ingress --group-id $id_sec_group --protocol tcp --port 3389 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress --group-id $id_sec_group --protocol tcp --port 22 --cidr 0.0.0.0/0

echo "4 Fin - Creación de SecurityGroups ($id_sec_group)"


echo "5 Inicio - Creación de Instancias"
aws ec2 run-instances --image-id ami-09d3b3274b6c5d4aa --count 1 --instance-type t2.micro --key-name AlexKeyPair --security-group-ids $id_sec_group --subnet-id $id_Subnet --tag-specifications 'ResourceType=instance,Tags=[{Key=NameInstance,Value=Test4Instance1}]' 
id_instancia_1=$(aws ec2 describe-instances --filters "Name=tag:NameInstance,Values=Test4Instance1"  --query "Reservations[].Instances[].InstanceId" --output text)

aws ec2 run-instances --image-id ami-09d3b3274b6c5d4aa --count 1 --instance-type t2.micro --key-name AlexKeyPair --security-group-ids $id_sec_group --subnet-id $id_Subnet --tag-specifications 'ResourceType=instance,Tags=[{Key=NameInstance,Value=Test4Instance2}]' 
id_instancia_2=$(aws ec2 describe-instances --filters "Name=tag:NameInstance,Values=Test4Instance2"  --query "Reservations[].Instances[].InstanceId" --output text)

aws ec2 run-instances --image-id ami-09d3b3274b6c5d4aa --count 1 --instance-type t2.micro --key-name AlexKeyPair --security-group-ids $id_sec_group --subnet-id $id_Subnet --tag-specifications 'ResourceType=instance,Tags=[{Key=NameInstance,Value=Test4Instance3}]' 
id_instancia_3=$(aws ec2 describe-instances --filters "Name=tag:NameInstance,Values=Test4Instance3"  --query "Reservations[].Instances[].InstanceId" --output text)

echo "5 Fin - Creación de Instancias ($id_instancia_1,$id_instancia_2,$id_instancia_3)"

echo "6 Inicio - Información de Instancias"

id_state_1=$(aws ec2 describe-instances --instance-id "$id_instancia_1" --query "Reservations[*].Instances[*].{State:State.Name}" --output text)
id_ip_1=$(aws ec2 describe-instances --instance-id "$id_instancia_1" --query "Reservations[*].Instances[*].{Address:PublicIpAddress}" --output text)

id_state_2=$(aws ec2 describe-instances --instance-id "$id_instancia_2" --query "Reservations[*].Instances[*].{State:State.Name}" --output text)
id_ip_2=$(aws ec2 describe-instances --instance-id "$id_instancia_2" --query "Reservations[*].Instances[*].{Address:PublicIpAddress}" --output text)

id_state_3=$(aws ec2 describe-instances --instance-id "$id_instancia_3" --query "Reservations[*].Instances[*].{State:State.Name}" --output text)
id_ip_3=$(aws ec2 describe-instances --instance-id "$id_instancia_3" --query "Reservations[*].Instances[*].{Address:PublicIpAddress}" --output text)



#Variables
staterun="running"
number=2

while [ $number -gt 1 ]
do

if [[ $id_state_1 = $staterun ]] && [[ $id_state_2 = $staterun ]] & [[ $id_state_3 = $staterun ]]
then
   number=$(($number-1))
else
	echo "Validación de estado"
    id_state_1=$(aws ec2 describe-instances --instance-id "$id_instancia_1" --query "Reservations[*].Instances[*].{State:State.Name}" --output text)
	id_state_2=$(aws ec2 describe-instances --instance-id "$id_instancia_2" --query "Reservations[*].Instances[*].{State:State.Name}" --output text)
	id_state_3=$(aws ec2 describe-instances --instance-id "$id_instancia_3" --query "Reservations[*].Instances[*].{State:State.Name}" --output text)
fi



done

echo "Instancia 1: $id_state_1 - IP $id_ip_1"
echo "Instancia 2: $id_state_2 - IP $id_ip_2"
echo "Instancia 3: $id_state_3 - IP $id_ip_3"

echo "6 Fin - Información de Instancias"

echo "7 Inicio - Conexión y Despliegue en Instancias"

ssh -i 'AlexKeyPair.pem' ec2-user@$id_ip_1 "sudo amazon-linux-extras install java-openjdk11 && sudo yum -y install java-1.8.0-openjdk"
ssh -i 'AlexKeyPair.pem' ec2-user@$id_ip_2 "sudo amazon-linux-extras install java-openjdk11 && sudo yum -y install java-1.8.0-openjdk"
ssh -i 'AlexKeyPair.pem' ec2-user@$id_ip_3 "sudo amazon-linux-extras install java-openjdk11 && sudo yum -y install java-1.8.0-openjdk"



echo "7 Fin - Conexión y Despliegue en Instancias"

#aws ec2 terminate-instances --instance-ids "$id_instancia_1"
#aws ec2 terminate-instances --instance-ids "$id_instancia_2"
#aws ec2 terminate-instances --instance-ids "$id_instancia_3"

