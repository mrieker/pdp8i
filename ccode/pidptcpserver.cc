//    Copyright (C) Mike Rieker, Beverly, MA USA
//    www.outerworldapps.com
//
//    This program is free software; you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation; version 2 of the License.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    EXPECT it to FAIL when someone's HeALTh or PROpeRTy is at RISk.
//
//    You should have received a copy of the GNU General Public License
//    along with this program; if not, write to the Free Software
//    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//    http://www.gnu.org/licenses/gpl-2.0.html

// runs on raspberry pi plugged into a pidp8 panel to serve up leds and switches
// this is a different pidp8 panel than the one plugged into the console board

// on raspi plugged into pidp8 panel:
//  ./pidptcpserver

// on the zynq:
//  ./pidptcpclient <hostname-of-raspi>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define ABORT() do { fprintf (stderr, "abort() %s:%d\n", __FILE__, __LINE__); abort (); } while (0)

#include "pidp.h"

static bool volatile ctrlcflag;
static PiDPMsg phymsg;
static PiDPMsg tcpmsg;

static void siginthand (int signum);
static void *phythread (void *dummy);

int main (int argc, char **argv)
{
    setlinebuf (stdout);

    struct sockaddr_in cliaddr;
    memset (&cliaddr, 0, sizeof cliaddr);
    cliaddr.sin_family = AF_INET;
    cliaddr.sin_port = htons (pidptcpport);

    int lisfd = socket (AF_INET, SOCK_STREAM, 0);
    if (lisfd < 0) ABORT ();

    int one = 1;
    if (setsockopt(lisfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one) < 0) ABORT ();

    if (bind (lisfd, (struct sockaddr *) &cliaddr, sizeof cliaddr) < 0) {
        fprintf (stderr, "pidptcpserver: error binding to %d: %m\n", pidptcpport);
        ABORT ();
    }

    if (listen (lisfd, 1) < 0) ABORT ();

    fprintf (stderr, "pidptcpserver: listening on %d\n", pidptcpport);

    signal (SIGINT,  siginthand);
    signal (SIGTERM, siginthand);

    pthread_t threadid;
    int rc = pthread_create (&threadid, NULL, phythread, NULL);
    if (rc != 0) ABORT ();

    while (true) {

        // lights off while waiting for inbound connection
        memset (&phymsg, 0, sizeof phymsg);

        // wait for inbound connection
        socklen_t addrlen = sizeof cliaddr;
        int confd = accept (lisfd, (sockaddr *) &cliaddr, &addrlen);
        if (confd < 0) {
            fprintf (stderr, "pidptcpserver: error accepting connection: %m\n");
            sleep (1);
            continue;
        }
        fprintf (stderr, "pidptcpserver: accepted from %s:%d\n",
            inet_ntoa (cliaddr.sin_addr), ntohs (cliaddr.sin_port));

        while (true) {

            // read lights from client
            int rc = read (confd, &tcpmsg, sizeof tcpmsg);
            if (rc != (int) sizeof tcpmsg) {
                if (rc < 0) {
                    fprintf (stderr, "pidptcpserver: error receiving packet: %m\n");
                } else if (rc == 0) {
                    fprintf (stderr, "pidptcpserver: client disconnected\n");
                } else {
                    fprintf (stderr, "pidptcpserver: only received %d bytes of %d\n", rc, (int) sizeof tcpmsg);
                }
                close (confd);
                break;
            }
            for (int i = 0; i < 8; i ++) phymsg.ledrows[i] = tcpmsg.ledrows[i];

            // send switches to client
            for (int i = 0; i < 3; i ++) tcpmsg.swrows[i] = phymsg.swrows[i];
            rc = write (confd, &tcpmsg, sizeof tcpmsg);
            if (rc != (int) sizeof tcpmsg) {
                if (rc < 0) {
                    fprintf (stderr, "pidptcpserver: error transmitting: %m\n");
                } else {
                    fprintf (stderr, "pidptcpserver: only transmitted %d bytes of %d\n", rc, (int) sizeof tcpmsg);
                }
                close (confd);
                break;
            }
        }
    }
}

static void siginthand (int signum)
{
    if (ctrlcflag) exit (1);
    ctrlcflag = true;
}

static void *phythread (void *dummy)
{
    pidp_open (NULL);
    while (! ctrlcflag) {
        pidp_proc (&phymsg);
    }
    exit (0);
    return NULL;
}
