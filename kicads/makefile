
default: Backpln.jar Layout.jar VeriPCB.jar

Backpln.jar: Backpln.java PCB.jar
	rm -f Backpln*.class Backpln.jar
	javac -cp PCB.jar:SCM.jar Backpln.java
	jar cf Backpln.jar Backpln*.class
	rm -f Backpln*.class

Layout.jar: Layout.java PCB.jar
	rm -f Layout*.class Layout.jar
	javac -cp PCB.jar:SCM.jar Layout.java
	jar cf Layout.jar Layout*.class
	rm -f Layout*.class

VeriPCB.jar: VeriPCB.java PCB.jar
	rm -f VeriPCB*.class VeriPCB.jar
	javac -cp PCB.jar:SCM.jar VeriPCB.java
	jar cf VeriPCB.jar VeriPCB*.class
	rm -f VeriPCB*.class

PCB.jar: PCB.java SCM.jar
	rm -f PCB*.class PCB.jar
	javac -cp SCM.jar PCB.java
	jar cf PCB.jar PCB*.class
	rm -f PCB*.class

SCM.jar: SCM.java
	rm -f SCM*.class SCM.jar
	javac SCM.java
	jar cf SCM.jar SCM*.class
	rm -f SCM*.class

