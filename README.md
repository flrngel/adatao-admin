===============
Spark-Admin
===============

The Spark-Admin provides administrators and developers a GUI to provision and manage Spark clusters easily. The current alpha version is based on Spark-EC2 script and its latest AMI. Support for different Linux distros is planned in the next version.

# Features
* Automatically detect existing Spark clusters created by spark-ec2 script
* Create new Spark clusters with friendly hostnames
* Start/Stop/Terminate Spark clusters
* Start/Stop/Restart services on the cluster (Mesos, Spark, Shark, Ganglia, HDFS, MapReduce)
* Execute Shark SQL query on the fly  
* Fully compatible with spark-ec2, you can use Spark-Admin and spark-ec2 script interchangeably

# Installation

Install PIP/PyCurl

* Ubuntu: `sudo apt-get install python-pip python-pycurl`
* RHEL/CentOS: `sudo yum install python-pip python-pycurl`
* Mac OS X: `sudo easy_install pip pycurl`
* Build from source: http://www.pip-installer.org/en/latest/installing.html#using-get-pip

Install Python dependencies

    sudo pip install tornado boto hive-thrift-py pycurl tornado-slacker

Clone this project

    git clone https://github.com/adatao/spark-admin.git

Put your Amazon private keys in the /keys directory under spark-admin. For example, if you want to create or manage clusters using `spark-key`, then copy `spark-key.pem` to /keys directory. Also remember to change all your .pem to mode `600` by using  

    chmod 600 spark-admin/keys/*.pem

Run spark-admin

    cd spark-admin
    python app.py

Then point your browser to `http://localhost:8888` and fill in the AWS credentials in the [Settings] menu

# FAQs

* **How to run Spark-Admin as background service?**

    You can run Spark-Admin as background service using command `nohup python app.py &` or via `supervisord`, but please notice that some features won't work properly such as: New cluster, Start cluster... due to problem in shell executing. Hopefully we can fix this annoying problem in the next version.

* **Where is web server log?**

    Please click on [Server Logs] in the GUI menu, or track it at `<spark-admin>/static/server.log`

* **I try to start Shark service, but nothing happens?**

    If you start Shark service on existing clusters created by spark-ec2 script, but not Spark-Admin, remember to open the port 10000 on the master for the Spark-Admin web server to talk to. Also starting Shark service may take a few seconds, then you can wait for around 5 seconds then refresh the page. 


# Screenshots

* Automatically detect existing Spark clusters

    ![Automatically detect existing Spark clusters](https://lh6.googleusercontent.com/-GNFBtzwkMyM/UW0bSEgowsI/AAAAAAAAACw/stJKCLeKUhk/s600/spark_admin_0.png)

* Manage installed services on the cluster

    ![Manage installed services on the cluster](https://lh5.googleusercontent.com/-UlvJn5l2GwU/UW0bSWKmkgI/AAAAAAAAACs/TeAj6ywgNk0/s600/spark_admin_1.png)

* Execute Shark query on the fly

    ![Execute Shark SQL](https://lh3.googleusercontent.com/-tHXdbE94yUc/UW0bSJt6RsI/AAAAAAAAACo/lZGJdRfcNI0/s600/spark_admin_1.png)

# Third-party software

* spark-ec2 script https://github.com/mesos/spark/tree/master/ec2
* Bootstrap http://twitter.github.io/bootstrap/
* JQuery http://jquery.com/
* CodeMirror http://codemirror.net/

# License

The license is BSD, the same as Spark.
