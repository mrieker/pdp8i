
default: Layout.jar VeriPCB.jar

Layout.jar: Layout.java PCB.jar
	rm -f Layout*.class Layout.jar
	javac -cp PCB.jar Layout.java
	jar cf Layout.jar Layout*.class
	rm -f Layout*.class

VeriPCB.jar: VeriPCB.java PCB.jar
	rm -f VeriPCB*.class VeriPCB.jar
	javac -cp PCB.jar VeriPCB.java
	jar cf VeriPCB.jar VeriPCB*.class
	rm -f VeriPCB*.class

PCB.jar: PCB.java
	rm -f PCB*.class PCB.jar
	javac PCB.java
	jar cf PCB.jar PCB*.class
	rm -f PCB*.class

