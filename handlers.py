from multiprocessing import Process
from sys import stderr
from threading import Thread
from tornado import gen
from utils import ssh
import os
import spark_ec2
import subprocess
import sys
import time
import tornado.web
import utils
from slacker import adisp
from slacker import Slacker
from slacker.workers import ThreadWorker

instance_types = ["m1.small", "m1.medium", "m1.large", "m1.xlarge", "m3.xlarge", "m3.2xlarge", "t1.micro", "m2.xlarge", "m2.2xlarge", "m2.4xlarge", "c1.medium", "c1.xlarge", "cc2.8xlarge", "cr1.8xlarge", "cg1.4xlarge", "hi1.4xlarge", "hs1.8xlarge"]

class NewClusterHandler(tornado.web.RequestHandler):
    def get(self):
        try:
            conn = utils.get_ec2_conn(self)
            key_pairs = conn.get_all_key_pairs()
            self.render('new_cluster.html', error_msg=None, key_pairs=key_pairs, instance_types=instance_types)
        except Exception as e:
            print >> stderr, (e)
            self.render('error.html', error_msg=str(e))
    def post(self):
        try:
            cluster_name = self.get_argument("cluster_name", "")
            if (cluster_name == ""):
                return self.render('error.html', error_msg="Cluster name is empty!")
            conn = utils.get_ec2_conn(self)
            (master_nodes, slave_nodes, zoo_nodes) = utils.get_existing_cluster(conn, cluster_name)
            if len(master_nodes) > 0:
                return self.render('error.html', error_msg="Cluster name is already existed!")
            num_slave                           = self.get_argument("num_slave", "2")
            key_pair                            = self.get_argument("key_pair", "")
            instance_type                       = self.get_argument("instance_type", "m1.small")
            master_instance_type                = self.get_argument("master_instance_type", "m1.small")
            zone                                = self.get_argument("zone", "us-east-1e")
            ebs_vol_size                        = self.get_argument("ebs_vol_size", "10")
            swap                                = self.get_argument("swap", "1024")
            cluster_type                        = self.get_argument("cluster_type", "mesos")
            (AWS_ACCESS_KEY, AWS_SECRET_KEY)    = utils.get_aws_credentials()
            os.environ['AWS_ACCESS_KEY_ID']     = AWS_ACCESS_KEY
            os.environ['AWS_SECRET_ACCESS_KEY'] = AWS_SECRET_KEY
            key_pair_file =  os.getcwd() + "/keys/" + key_pair + ".pem" 
            #sys.argv = ["spark_ec2.py", "-s", num_slave, "-u", "root", "-k", key_pair, "-i", key_pair_file, "-t", instance_type, "-m", master_instance_type, "-r", "us-east-1", "-z" , zone, "--ebs-vol-size=" + ebs_vol_size, "--swap=" + swap, "--cluster-type=" + cluster_type, "launch", cluster_name]
            #t = Thread(target=spark_ec2.main, args=())
            #t.daemon = True
            #t.start()

            command = ["release/launch-cluster.sh", cluster_name, num_slave, "--elastic-ip", "54.197.232.5", "--ami", "ami-1b050872"]
            print ("Running : " + ' '.join(command))
            subprocess.Popen(command)
            self.redirect("/")
        except Exception as e:
            print >> stderr, (e)
            self.render('error.html', error_msg=str(e))

class HomeHandler(tornado.web.RequestHandler):
    def get(self):
        try:
            conn = utils.get_ec2_conn(self)
            (cluster_names, dict_masters, dict_slaves) = utils.detect_existing_clusters(conn) 
            self.render('home.html', error_msg=None, cluster_names=cluster_names, dict_masters=dict_masters, dict_slaves=dict_slaves)
        except Exception as e:
            print >> stderr, (e)
            self.render('error.html', error_msg=str(e))

class ClusterHandler(tornado.web.RequestHandler):
    def get(self, cluster_name):
        try:
            conn = utils.get_ec2_conn(self)
            (master_nodes, slave_nodes, zoo_nodes) = utils.get_existing_cluster(conn, cluster_name)
            services = ["mesos", "shark", "ganglia", "ephemeral_hdfs", "persistent_hdfs", "hadoop_mapreduce", "pi", "pa", "gridftp", "spark"]
            service_names = {
                "mesos"             : "Mesos", 
                "shark"             : "Shark", 
                "ganglia"           : "Ganglia", 
                "ephemeral_hdfs"    : "Ephemeral HDFS", 
                "persistent_hdfs"   : "Persistent HDFS", 
                "hadoop_mapreduce"  : "Hadoop MapReduce", 
                "pa"                : "Adatao pAnalytics", 
                "pi"                : "Adatao pInsights", 
                "gridftp"           : "Grid FTP", 
                "spark"             : "Spark"}
            service_ports = {
                "mesos"             : 5050, 
                "shark"             : 10000, 
                "ganglia"           : 5080, 
                "ephemeral_hdfs"    : 50070, 
                "persistent_hdfs"   : 60070, 
                "hadoop_mapreduce"  : 50030, 
                "pa"                : 7911,
                "pi"                : 8890, 
                "gridftp"           : 5000, 
                "spark"             : 30001}
            service_links = {
                "mesos"             : "http://" + master_nodes[0].public_dns_name + ":5050", 
                "shark"             : "/sql_console?server=" + master_nodes[0].public_dns_name, 
                "ganglia"           : "http://" + master_nodes[0].public_dns_name + ":5080/ganglia", 
                "ephemeral_hdfs"    : "http://" + master_nodes[0].public_dns_name + ":50070", 
                "persistent_hdfs"   : "http://" + master_nodes[0].public_dns_name + ":60070", 
                "hadoop_mapreduce"  : "http://" + master_nodes[0].public_dns_name + ":50030",
                "pa"                : "", 
                "pi"                : "http://" + master_nodes[0].public_dns_name + ":8890",
                "gridftp"           : "", 
                "spark"             : "http://" + master_nodes[0].public_dns_name + ":30001"}
            service_statuses = {}
            if len(master_nodes) > 0:
                dns = master_nodes[0].public_dns_name
                for service in services:
                    port = service_ports[service]
                    service_statuses[service] = utils.isOpen(dns, port)
                    if service == "shark" and service_statuses[service]:
                        service_names[service] = "Shark (SQL Console)"
            self.render('cluster.html', error_msg=None, cluster_name=cluster_name, master_nodes=master_nodes, slave_nodes=slave_nodes, services=services, service_names=service_names, service_statuses=service_statuses, service_links=service_links)
        except Exception as e:
            print >> stderr, (e)
            self.render('error.html', error_msg=str(e))

class AboutHandler(tornado.web.RequestHandler):
    def get(self):
        self.render('about.html')                

class SettingsHandler(tornado.web.RequestHandler):
    def get(self):
        (AWS_ACCESS_KEY, AWS_SECRET_KEY) = utils.get_aws_credentials()
        self.render('settings.html', AWS_ACCESS_KEY=AWS_ACCESS_KEY, AWS_SECRET_KEY=AWS_SECRET_KEY, error_code= -1)
    def post(self):
        AWS_ACCESS_KEY = self.get_argument("AWS_ACCESS_KEY", "")
        AWS_SECRET_KEY = self.get_argument("AWS_SECRET_KEY", "")
        if AWS_ACCESS_KEY == "" or AWS_SECRET_KEY == "":
            error_code = 1
            error_msg = "Please fill in both Access key and Secret key!"
        else:
            error_code = 0
            error_msg = "Update successfully!"
            utils.save_aws_credentials(AWS_ACCESS_KEY, AWS_SECRET_KEY)
        self.render('settings.html', AWS_ACCESS_KEY=AWS_ACCESS_KEY, AWS_SECRET_KEY=AWS_SECRET_KEY, error_code=error_code, error_msg=error_msg)

async_execute_sql = Slacker(utils.executeSql, ThreadWorker())

class SqlConsoleHandler(tornado.web.RequestHandler):
    def get(self):
        try:
            self.render('sql_console.html', error_msg=None, code="show tables", server=self.get_argument("server", "localhost"), result="")
        except Exception as e:
            print >> stderr, (e)
            self.render('error.html', error_msg=str(e))
    @tornado.web.asynchronous
    @adisp.process
    def post(self):
        try:
            server = self.get_argument("server", "localhost")
            code = self.get_argument("code", "")
            result = yield async_execute_sql(server, code)
            self.render('sql_console.html', error_msg=None, code=code, server=server, result=result)
        except Exception as e:
            print >> stderr, (e)
            self.render('error.html', error_msg=str(e))

async_ssh = Slacker(ssh, ThreadWorker())

class ActionHandler(tornado.web.RequestHandler):
    @tornado.web.asynchronous
    @adisp.process
    def get(self):
        try:
            cluster_name = self.get_argument("cluster_name", "")
            dns = self.get_argument("dns", "")
            service = self.get_argument("service", "")
            action = self.get_argument("action", "")
            key_pair = self.get_argument("key_pair", "")
            key_pair_file = os.getcwd() + "/keys/" + key_pair + ".pem"
            
            # Execute action
            if service == "mesos":
                if action == "start":
                    yield async_ssh(key_pair_file, dns, "spark-ec2/mesos/start-mesos")
                elif action == "stop":
                    yield async_ssh(key_pair_file, dns, "spark-ec2/mesos/stop-mesos")
                elif action == "restart":
                    yield async_ssh(key_pair_file, dns, "spark-ec2/mesos/stop-mesos && spark-ec2/mesos/start-mesos")
            elif service == "shark":
                if action == "start":
                    command = (("rsync --ignore-existing -rv -e 'ssh -o StrictHostKeyChecking=no -i %s' " + 
                                "'%s/' 'root@%s:/root/shark-0.2/conf'") % (key_pair_file, 'deploy.shark', dns))
                    subprocess.check_call(command, shell=True)
                    yield async_ssh(key_pair_file, dns, "nohup ~/shark-0.2/bin/shark --service sharkserver >/dev/null &")
                    time.sleep(2)  # Wait for Shark to restart
                elif action == "stop":
                    yield async_ssh(key_pair_file, dns, "ps ax|grep shark.SharkServer|awk \"{print $1}\"|xargs kill")
                elif action == "restart":
                    yield async_ssh(key_pair_file, dns, "ps ax|grep shark.SharkServer|awk '{print $1}'|xargs kill && nohup ~/shark-0.2/bin/shark --service sharkserver >/dev/null &")
                    time.sleep(2)  # Wait for Shark to restart
            elif service == "ganglia":
                if action == "start":
                    yield async_ssh(key_pair_file, dns, "/etc/init.d/gmetad start && /etc/init.d/httpd start")
                elif action == "stop":
                    yield async_ssh(key_pair_file, dns, "/etc/init.d/gmetad stop && /etc/init.d/httpd stop")
                elif action == "restart":
                    yield async_ssh(key_pair_file, dns, "/etc/init.d/gmetad restart && /etc/init.d/httpd restart")
            elif service == "ephemeral_hdfs":
                if action == "start":
                    yield async_ssh(key_pair_file, dns, "~/ephemeral-hdfs/bin/start-dfs.sh")
                elif action == "stop":
                    yield async_ssh(key_pair_file, dns, "~/ephemeral-hdfs/bin/stop-dfs.sh")
                elif action == "restart":
                    yield async_ssh(key_pair_file, dns, "~/ephemeral-hdfs/bin/stop-dfs.sh && ~/ephemeral-hdfs/bin/start-dfs.sh")
            elif service == "persistent_hdfs":
                if action == "start":
                    yield async_ssh(key_pair_file, dns, "~/persistent-hdfs/bin/start-dfs.sh")
                elif action == "stop":
                    yield async_ssh(key_pair_file, dns, "~/persistent-hdfs/bin/stop-dfs.sh")
                elif action == "restart":
                    yield async_ssh(key_pair_file, dns, "~/persistent-hdfs/bin/stop-dfs.sh && ~/persistent-hdfs/bin/start-dfs.sh")
            elif service == "hadoop_mapreduce":
                if action == "start":
                    yield async_ssh(key_pair_file, dns, "~/ephemeral-hdfs/bin/start-mapred.sh")
                elif action == "stop":
                    yield async_ssh(key_pair_file, dns, "~/ephemeral-hdfs/bin/stop-mapred.sh")
                elif action == "restart":
                    yield async_ssh(key_pair_file, dns, "~/ephemeral-hdfs/bin/stop-mapred.sh && ~/ephemeral-hdfs/bin/start-mapred.sh")
            elif service == "cluster":
                if action == "start":
                    (AWS_ACCESS_KEY, AWS_SECRET_KEY) = utils.get_aws_credentials()
                    os.environ['AWS_ACCESS_KEY_ID'] = AWS_ACCESS_KEY
                    os.environ['AWS_SECRET_ACCESS_KEY'] = AWS_SECRET_KEY
                    #sys.argv = ["spark_ec2.py", "-u", "root", "-k", key_pair, "-i", key_pair_file, "start", cluster_name]
                    #t = Thread(target=spark_ec2.main, args=())
                    #t.daemon = True
                    #t.start()
                    command = ["release/start-cluster.sh", cluster_name, "--elastic-ip", "54.197.232.5"]
                    print ("Running : " + ' '.join(command))
                    subprocess.Popen(command)
                    self.redirect("/")
                    return
                elif action == "stop":
                    command = ["release/stop-cluster.sh", cluster_name]
                    print ("Running : " + ' '.join(command))
                    subprocess.Popen(command)
                    time.sleep(1)
                    self.redirect("/")
                    return
                elif action == "terminate": 
                    command = ["release/terminate-cluster.sh", cluster_name]
                    print ("Running : " + ' '.join(command))
                    subprocess.Popen(command)
                    time.sleep(1)
                    self.redirect("/")
                    return
            time.sleep(1)
            self.redirect("/cluster/" + cluster_name)
        except Exception as e:
            # print >> stderr, (e)
            self.render('error.html', error_msg=str(e))
