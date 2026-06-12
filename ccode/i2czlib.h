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

#ifndef _I2CZLIB_H
#define _I2CZLIB_H

#include <stdint.h>

#define DOTJMPDOT 05252U

#include "z8iutil.h"

// toggle switches
struct Z8IToggles {
    uint16_t sr;
    uint8_t dfld;
    uint8_t ifld;
    bool sinst;
    bool sstep;
};

// button (momentary) switches
struct Z8IButtons {
    bool stop;
    bool cont;
    bool start;
    bool ldad;
    bool exam;
    bool dep;
};

// light bulbs
struct Z8ILights {
    uint16_t ac;
    uint16_t ma;
    uint16_t mb;
    uint16_t mq;
    uint16_t pc;
    uint8_t dfld;
    uint8_t ifld;
    uint8_t ema;
    uint8_t ir;
    uint8_t ms;
    uint8_t sc;
    bool link;
    bool ion;
    bool pau;
    bool run;
};

// all switches and lights
struct Z8IPanel {
    Z8IToggles togovr;  // which toggles are being overridden
    Z8IToggles togval;  // toggle switch values
    Z8IButtons button;  // button switch values
    Z8ILights  light;   // light bulb values
};

struct I2CZLib {
    I2CZLib ();
    ~I2CZLib ();
    void relall ();
    void readpads (Z8IPanel *pads);
    void writepads (Z8IPanel const *pads);

    void loop52 ();

private:
    Z8IU32 *pdpat;
    Z8IU32 *fpat;
};

#endif
