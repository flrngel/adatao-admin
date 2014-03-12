from boto import ec2
import sys
import csv
from socket import * 
from hive_service import ThriftHive
from hive_service.ttypes import HiveServerException
from thrift import Thrift
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol
import time
import subprocess
import ConfigParser

CONFIG_FILE = "static/config.properties"
SOCKET_TIME_OUT = 3  # Timeout in seconds, to check whether port is open

def executeSql(host, command):
    try:
        transport = TSocket.TSocket(host, 10000)
        transport = TTransport.TBufferedTransport(transport)
        protocol = TBinaryProtocol.TBinaryProtocol(transport)
        client = ThriftHive.Client(protocol)
        transport.open()
        sqls = command.replace("\r\n", "").split(";")
        result = []
        for sql in sqls:
            sql = sql.strip()
            if len(sql) > 0:
                start = time.time()
                client.execute(sql)
                lines = client.fetchAll()
                end = time.time()
                result = result + lines + ["----------Time: %.3fs----------" % (end-start)]
        transport.close()
        return result
    except Exception as e:
        return [str(e)]

def ssh(key_pair, host, command):
    try:
        c = "ssh -o StrictHostKeyChecking=no -i %s root@%s '%s'" % (key_pair, host, command)
        print "Execute: " + c
        subprocess.check_call(c, shell=True)
    except Exception as e:
        print (e)

def isOpen(ip, port):
	s = socket(AF_INET, SOCK_STREAM)
	s.settimeout(SOCKET_TIME_OUT)
	result = s.connect_ex((ip, port))
	if(result == 0):
		s.close()
		return True
	else:
		return False
            
def get_ec2_conn(self):
	(AWS_ACCESS_KEY, AWS_SECRET_KEY) = get_aws_credentials()
	if AWS_ACCESS_KEY == "" or AWS_SECRET_KEY == "":
		self.render('home.html', error_msg="Please visit Settings page and set the AWS credentials to proceed!")
	conn = ec2.connect_to_region("us-east-1", aws_access_key_id=AWS_ACCESS_KEY, aws_secret_access_key=AWS_SECRET_KEY)
	return conn

def get_aws_credentials():
    config = ConfigParser.ConfigParser()
    config.read(CONFIG_FILE)
    AWS_ACCESS_KEY = ""
    AWS_SECRET_KEY = ""
    if config.has_section("AWS"):
	   AWS_ACCESS_KEY = config.get("AWS", "AWS_ACCESS_KEY", "")
	   AWS_SECRET_KEY = config.get("AWS", "AWS_SECRET_KEY", "")
    return (AWS_ACCESS_KEY, AWS_SECRET_KEY)

def save_aws_credentials(AWS_ACCESS_KEY, AWS_SECRET_KEY):
	config = ConfigParser.ConfigParser()
	config.add_section('AWS')
	config.set('AWS', 'AWS_ACCESS_KEY', AWS_ACCESS_KEY)
	config.set('AWS', 'AWS_SECRET_KEY', AWS_SECRET_KEY)
	cfgfile = open(CONFIG_FILE, 'w')
	config.write(cfgfile)

def get_elastic_ip(cluster_name):
	reader = csv.reader(open('dict.csv', 'r+'))
	mydict = dict(x for x in reader)
	if cluster_name in mydict:
		ip = mydict[cluster_name]
		print "Cluster " + cluster_name + " found with elastic ip " + ip
		return ip
	else:
		print "Cluster " + cluster_name + " not found!"

def set_elastic_ip(cluster_name, elastic_ip):
	reader = csv.reader(open('dict.csv', 'r+'))
	mydict = dict(x for x in reader)
	mydict[cluster_name] = elastic_ip
	writer = csv.writer(open('dict.csv', 'wb'))
	for key, value in mydict.items():
		writer.writerow([key, value])

def delete_elastic_ip(cluster_name):
	reader = csv.reader(open('dict.csv', 'r+'))
	mydict = dict(x for x in reader)
	if cluster_name in mydict:
		ip = mydict[cluster_name]
		print "Cluster " + cluster_name + " found with elastic ip " + ip + " ... removing ..."
		mydict.remove(cluster_name)
		writer = csv.writer(open('dict.csv', 'wb'))
		for key, value in mydict.items():
			writer.writerow([key, value])
	else:
		print "Cluster " + cluster_name + " not found!"

def detect_existing_clusters(conn):
	reservations = conn.get_all_instances()
	master_names = []
	slave_names = []
	for res in reservations:
		master_names += [g.name.replace("-master", "") for g in res.groups if g.name.endswith("-master")]
		slave_names += [g.name.replace("-slaves", "") for g in res.groups if g.name.endswith("-slaves")]
	names = set(master_names) & set(slave_names)
	dict_masters = {}
	dict_slaves = {}
	for name in names:
		master_nodes = []
		slave_nodes = []
		for res in reservations:
			group_names = [g.name for g in res.groups]
			if group_names == [name + "-master"]:
				master_nodes += res.instances
			elif group_names == [name + "-slaves"]:
				slave_nodes += res.instances
		dict_masters[name] = master_nodes
		dict_slaves[name] = slave_nodes
	return (names, dict_masters, dict_slaves)

def get_existing_cluster(conn, cluster_name, die_on_error=True):
	print "Searching for existing cluster " + cluster_name + "..."
	reservations = conn.get_all_instances()
	master_nodes = []
	slave_nodes = []
	zoo_nodes = []
	for res in reservations:
		group_names = [g.name for g in res.groups]
		if group_names == [cluster_name + "-master"]:
			master_nodes += res.instances
		elif group_names == [cluster_name + "-slaves"]:
			slave_nodes += res.instances
		elif group_names == [cluster_name + "-zoo"]:
			zoo_nodes += res.instances
	if any((master_nodes, slave_nodes, zoo_nodes)):
		print ("Found %d master(s), %d slaves, %d ZooKeeper nodes" % 
		       (len(master_nodes), len(slave_nodes), len(zoo_nodes)))
	if (master_nodes != [] and slave_nodes != []) or not die_on_error:
		return (master_nodes, slave_nodes, zoo_nodes)
	else:
		if master_nodes == [] and slave_nodes != []:
			print "ERROR: Could not find master in group " + cluster_name + "-master"
		elif master_nodes != [] and slave_nodes == []:
			print "ERROR: Could not find slaves in group " + cluster_name + "-slaves"
		else:
			print "ERROR: Could not find any existing cluster"
		return (master_nodes, slave_nodes, zoo_nodes)
