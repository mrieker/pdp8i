
default: Align.jar Backpln.jar Layout.jar Renum.jar TesterDefs.jar VeriPCB.jar ZTurnPins.jar

Align.jar: Align.java PCB.jar
	rm -f Align*.class Align.jar
	javac -cp PCB.jar:SCM.jar Align.java
	jar cf Align.jar Align*.class
	rm -f Align*.class

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

Renum.jar: Renum.java PCB.jar
	rm -f Renum*.class Renum.jar
	javac -cp PCB.jar:SCM.jar Renum.java
	jar cf Renum.jar Renum*.class
	rm -f Renum*.class

TesterDefs.jar: TesterDefs.java PCB.jar
	rm -f TesterDefs*.class TesterDefs.jar
	javac -cp PCB.jar:SCM.jar TesterDefs.java
	jar cf TesterDefs.jar TesterDefs*.class
	rm -f TesterDefs*.class

VeriPCB.jar: VeriPCB.java PCB.jar
	rm -f VeriPCB*.class VeriPCB.jar
	javac -cp PCB.jar:SCM.jar VeriPCB.java
	jar cf VeriPCB.jar VeriPCB*.class
	rm -f VeriPCB*.class

ZTurnPins.jar: ZTurnPins.java PCB.jar
	rm -f ZTurnPins*.class ZTurnPins.jar
	javac -cp PCB.jar:SCM.jar ZTurnPins.java
	jar cf ZTurnPins.jar ZTurnPins*.class
	rm -f ZTurnPins*.class

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

