Lago Demo
====================================

About
^^^^^^

In this demo we will learn how to set up basic environments with Lago.
The first environment will consist of two virtual machines with no customisation at all.
The second environment will consist of three virtual machines that will host Jenkins infrastructure.

The VMs
^^^^^^^

-  "vm1" - First machine
-  "vm2" - Second machine

The network
^^^^^^^^^^^^

The vms will be connected to the same network, There will be also connectivity between the vms host and the internet.

Prerequisite
^^^^^^^^^^^^^

- `Install Lago <http://lago.readthedocs.io/en/latest/README.html#installation>`_
- Clone this repository to your machine.

::

    git clone https://github.com/lago-project/Lago-Demo.git

Let's start !
^^^^^^^^^^^^^^

To begin, we will deploy two simple vms
From within the cloned repository, run the following commands:

-  Create the environment.
Note it used LagoInitFile within the current directory as default

::

    lago init

-  Start the vms.

::

    lago start

-   Installing the vms:
   -  Jenkins will be installed on the server.
   -  OpenJDK will be installed on the slaves.

::

    lago deploy

The environment is ready!
Now you can ssh vm1-ip. How to figure out what is the ip of "vm1" ?
Check out the following commands:

- Open a shell to vm1 (for any other vm, just replace 'vm1' with the name of the machine)

::

    lago shell vm1

- Print some usefull information about the environment.

::

    lago status

When you done with the enviroment:

- Turn off the vms.

::

    lago stop



Note:
 To turn on the vms, use::

::

    lago start

And if you will not have a need for the environment in the future:

- Delete the vms.

::

    lago destroy

Jenkins example
^^^^^^^^^^^^^^^

In this scenario, we will deploy 3 vms, one jenkins server with two slaves.

The VMs
^^^^^^^

-  "vm0-server" - Jenkins server
-  "vm1-slave" - Jenkins slave
-  "vm2-slave" - Jenkins slave

Lets init the environment with a specific configuration file.
Note it also used the metadata key to pass a specific script for each machine

::

    lago init LagoInitFile.jenkins

Once the environment is deployed, open your favorite browser, enter "vm0-server-ip-adress:8080" and the jenkins dashboard will be opened!


Advanced stuff
^^^^^^^^^^^^^^^

For more advanced stuff please check out `this <http://lago.readthedocs.io/en/latest/index.html>`__ tutorial
