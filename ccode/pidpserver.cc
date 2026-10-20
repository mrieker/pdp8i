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
//  ./pidpserver [-tcp]

// on the zynq:
//  ./pidpclient [-tcp] <hostname-of-raspi>

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

    bool usetcp = false;
    for (int i = 0; ++ i < argc;) {
        if (strcasecmp (argv[i], "-tcp") == 0) {
            usetcp = true;
            continue;
        }
        if (argv[i][0] == '-') {
            fprintf (stderr, "unknown option %s\n", argv[i]);
            return 1;
        }
        fprintf (stderr, "unknown parameter %s\n", argv[i]);
        return 1;
    }

    struct sockaddr_in cliaddr;
    memset (&cliaddr, 0, sizeof cliaddr);
    cliaddr.sin_family = AF_INET;
    cliaddr.sin_port = htons (pidpport);

    int confd = -1;
    int lisfd = -1;

    if (usetcp) {
        lisfd = socket (AF_INET, SOCK_STREAM, 0);
        if (lisfd < 0) ABORT ();

        int one = 1;
        if (setsockopt(lisfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one) < 0) ABORT ();

        if (bind (lisfd, (struct sockaddr *) &cliaddr, sizeof cliaddr) < 0) {
            fprintf (stderr, "pidpserver: error binding to tcp %d: %m\n", pidpport);
            ABORT ();
        }

        if (listen (lisfd, 1) < 0) ABORT ();
    } else {
        confd = socket (AF_INET, SOCK_DGRAM, 0);
        if (confd < 0) ABORT ();

        if (bind (confd, (struct sockaddr *) &cliaddr, sizeof cliaddr) < 0) {
            fprintf (stderr, "pidpserver: error binding to udp %d: %m\n", pidpport);
            ABORT ();
        }
    }

    fprintf (stderr, "pidpserver: listening on %d\n", pidpport);

    signal (SIGINT,  siginthand);
    signal (SIGTERM, siginthand);

    pthread_t threadid;
    int rc = pthread_create (&threadid, NULL, phythread, NULL);
    if (rc != 0) ABORT ();

    while (true) {

        // lights off while waiting for inbound connection
        memset (&phymsg, 0, sizeof phymsg);

        if (usetcp) {

            // wait for inbound connection
            socklen_t addrlen = sizeof cliaddr;
            confd = accept (lisfd, (sockaddr *) &cliaddr, &addrlen);
            if (confd < 0) {
                fprintf (stderr, "pidpserver: error accepting connection: %m\n");
                sleep (1);
                continue;
            }
            fprintf (stderr, "pidpserver: accepted from %s:%d\n",
                inet_ntoa (cliaddr.sin_addr), ntohs (cliaddr.sin_port));
        }

        uint64_t lastudpseq = 0;

        while (true) {

            // read lights from client
            if (usetcp) {

                int rc = read (confd, &tcpmsg, sizeof tcpmsg);
                if (rc != (int) sizeof tcpmsg) {
                    if (rc < 0) {
                        fprintf (stderr, "pidpserver: error receiving packet: %m\n");
                    } else if (rc == 0) {
                        fprintf (stderr, "pidpserver: client disconnected\n");
                    } else {
                        fprintf (stderr, "pidpserver: only received %d bytes of %d\n", rc, (int) sizeof tcpmsg);
                    }
                    close (confd);
                    confd = -1;
                    break;
                }
            } else {
                do {
                    socklen_t addrlen = sizeof cliaddr;
                    int rc = recvfrom (confd, &tcpmsg, sizeof tcpmsg, MSG_TRUNC, (sockaddr *) &cliaddr, &addrlen);
                    if (rc != (int) sizeof tcpmsg) {
                        if (rc < 0) {
                            fprintf (stderr, "pidpserver: error receiving packet: %m\n");
                        } else {
                            fprintf (stderr, "pidpserver: only received %d bytes of %d\n", rc, (int) sizeof tcpmsg);
                        }
                        ABORT ();
                    }
                } while (lastudpseq >= tcpmsg.seq);
                lastudpseq = tcpmsg.seq;
            }

            for (int i = 0; i < 8; i ++) phymsg.ledrows[i] = tcpmsg.ledrows[i];

            // send switches to client
            for (int i = 0; i < 3; i ++) tcpmsg.swrows[i] = phymsg.swrows[i];

            if (usetcp) {
                int rc = write (confd, &tcpmsg, sizeof tcpmsg);
                if (rc != (int) sizeof tcpmsg) {
                    if (rc < 0) {
                        fprintf (stderr, "pidpserver: error transmitting: %m\n");
                    } else {
                        fprintf (stderr, "pidpserver: only transmitted %d bytes of %d\n", rc, (int) sizeof tcpmsg);
                    }
                    close (confd);
                    confd = -1;
                    break;
                }
            } else {
                int rc = sendto (confd, &tcpmsg, sizeof tcpmsg, 0, (sockaddr *) &cliaddr, sizeof cliaddr);
                if (rc != (int) sizeof tcpmsg) {
                    if (rc < 0) {
                        fprintf (stderr, "pidpserver: error transmitting: %m\n");
                    } else {
                        fprintf (stderr, "pidpserver: only transmitted %d bytes of %d\n", rc, (int) sizeof tcpmsg);
                    }
                }
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
    pidp_open (NULL, false);
    while (! ctrlcflag) {
        pidp_proc (&phymsg);
    }
    exit (0);
    return NULL;
}
