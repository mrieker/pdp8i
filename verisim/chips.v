
module X74HC00 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , output reg p3
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , output reg p11
        , input      p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc, dd;

    always @(posedge zclock) begin
        { p3,  aa } <= { aa, ~ (p1  & p2)  };
        { p6,  bb } <= { bb, ~ (p4  & p5)  };
        { p8,  cc } <= { cc, ~ (p9  & p10) };
        { p11, dd } <= { dd, ~ (p12 & p13) };
    end
endmodule

module X74LS00 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , output p3
        , input  p4
        , input  p5
        , output p6
        , input  p7
        , output p8
        , input  p9
        , input  p10
        , output p11
        , input  p12
        , input  p13
        , input  p14
);

    X74HC00 hc (yclock, zclock, zreset, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14);
endmodule

module X74HC02 (input yclock, zclock, zreset,
          output reg p1
        , input      p2
        , input      p3
        , output reg p4
        , input      p5
        , input      p6
        , input      p7
        , input      p8
        , input      p9
        , output reg p10
        , input      p11
        , input      p12
        , output reg p13
        , input      p14
);

    reg[2:0] aa, bb, cc, dd;

    always @(posedge zclock) begin
        { p1,  aa } <= { aa, ~ (p2  | p3)  };
        { p4,  bb } <= { bb, ~ (p5  | p6)  };
        { p10, cc } <= { cc, ~ (p8  | p9)  };
        { p13, dd } <= { dd, ~ (p11 | p12) };
    end
endmodule

module X74LS02 (input yclock, zclock, zreset,
          output p1
        , input  p2
        , input  p3
        , output p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , input  p9
        , output p10
        , input  p11
        , input  p12
        , output p13
        , input  p14
);

    X74HC02 hc (yclock, zclock, zreset, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14);
endmodule

module X74HC04 (input yclock, zclock, zreset,
          input      p1
        , output reg p2
        , input      p3
        , output reg p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , output reg p10
        , input      p11
        , output reg p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc, dd, ee, ff;

    always @(posedge zclock) begin
        { p2,  aa } <= { aa, ~ p1  };
        { p4,  bb } <= { bb, ~ p3  };
        { p6,  cc } <= { cc, ~ p5  };
        { p8,  dd } <= { dd, ~ p9  };
        { p10, ee } <= { ee, ~ p11 };
        { p12, ff } <= { ff, ~ p13 };
    end
endmodule

module X74LS04 (input yclock, zclock, zreset,
          input  p1
        , output p2
        , input  p3
        , output p4
        , input  p5
        , output p6
        , input  p7
        , output p8
        , input  p9
        , output p10
        , input  p11
        , output p12
        , input  p13
        , input  p14
);

    X74HC04 hc (yclock, zclock, zreset, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14);
endmodule

module X74LS08 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , output reg p3
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , output reg p11
        , input      p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc, dd;

    always @(posedge zclock) begin
        { p3,  aa } <= { aa, p1  & p2  };
        { p6,  bb } <= { bb, p4  & p5  };
        { p8,  cc } <= { cc, p9  & p10 };
        { p11, dd } <= { dd, p12 & p13 };
    end
endmodule

module X74LS10 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p3
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , input      p11
        , output reg p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc;

    always @(posedge zclock) begin
        { p6,  aa } <= { aa, ~ (p3 & p4  & p5)  };
        { p8,  bb } <= { bb, ~ (p9 & p10 & p11) };
        { p12, cc } <= { cc, ~ (p1 & p2  & p13) };
    end
endmodule

module X74LS11 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p3
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , input      p11
        , output reg p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc;

    always @(posedge zclock) begin
        { p6,  aa } <= { aa, p3 & p4  & p5  };
        { p8,  bb } <= { bb, p9 & p10 & p11 };
        { p12, cc } <= { cc, p1 & p2  & p13 };
    end
endmodule

module X74LS20 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , input      p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb;

    always @(posedge zclock) begin
        { p6, aa } <= { aa, ~ (p1 & p2  & p4  & p5)  };
        { p8, bb } <= { bb, ~ (p9 & p10 & p12 & p13) };
    end
endmodule

module X74LS21 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , input      p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb;

    always @(posedge zclock) begin
        { p6, aa } <= { aa, p1 & p2  & p4  & p5  };
        { p8, bb } <= { bb, p9 & p10 & p12 & p13 };
    end
endmodule

module X74HC27 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p3
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , input      p11
        , output reg p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc;

    always @(posedge zclock) begin
        { p6,  aa } <= { aa, ~ (p3 | p4  | p5)  };
        { p8,  bb } <= { bb, ~ (p9 | p10 | p11) };
        { p12, cc } <= { cc, ~ (p1 | p2  | p13) };
    end
endmodule

module X74LS27 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output p6
        , input  p7
        , output p8
        , input  p9
        , input  p10
        , input  p11
        , output p12
        , input  p13
        , input  p14
);

    X74HC27 hc (yclock, zclock, zreset, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14);
endmodule

module X74LS30 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p3
        , input      p4
        , input      p5
        , input      p6
        , input      p7
        , output reg p8
        , input      p11
        , input      p12
        , input      p14
);

    reg[2:0] aa;

    always @(posedge zclock) begin
        { p8, aa } <= { aa, ~ (p1 & p2 & p3 & p4 & p5 & p6 & p11 & p12) };
    end
endmodule

module X74LS32 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , output reg p3
        , input      p4
        , input      p5
        , output reg p6
        , input      p7
        , output reg p8
        , input      p9
        , input      p10
        , output reg p11
        , input      p12
        , input      p13
        , input      p14
);

    reg[2:0] aa, bb, cc, dd;

    always @(posedge zclock) begin
        { p3,  aa } <= { aa, p1  | p2  };
        { p6,  bb } <= { bb, p4  | p5  };
        { p8,  cc } <= { cc, p9  | p10 };
        { p11, dd } <= { dd, p12 | p13 };
    end
endmodule

module X74LS42 (input yclock, zclock, zreset,
          output reg p1
        , output reg p2
        , output reg p3
        , output reg p4
        , output reg p5
        , output reg p6
        , output reg p7
        , input  p8
        , output reg p9
        , output reg p10
        , output reg p11
        , input  p12
        , input  p13
        , input  p14
        , input  p15
        , input  p16
);

    reg[19:00] delay;
    reg[3:0] n;

    assign p1  = (n != 0);
    assign p2  = (n != 1);
    assign p3  = (n != 2);
    assign p4  = (n != 3);
    assign p5  = (n != 4);
    assign p6  = (n != 5);
    assign p7  = (n != 6);
    assign p9  = (n != 7);
    assign p10 = (n != 8);
    assign p11 = (n != 9);

    always @(posedge zclock) begin
        { n, delay } <= { delay, p12, p13, p14, p15 };
    end
endmodule

module X74HC74 (input yclock, zclock, zreset,
          input      p1     // 1 _pc
        , input      p2     // 1 D
        , input      p3     // 1 T
        , input      p4     // 1 _ps
        , output reg p5     // 1 Q
        , output reg p6     // 1 _Q
        , input      p7     // GND
        , output reg p8     // 2 _Q
        , output reg p9     // 2 Q
        , input      p10    // 2 _ps
        , input      p11    // 2 T
        , input      p12    // 2 D
        , input      p13    // 2 _pc
        , input      p14    // VCC
);

    reg d1, d2, lastt1, lastt2;
    reg[1:0] setup1, setup2;
    reg[5:0] prop1, prop2, _prop1, _prop2;

    always @(posedge zclock) begin
        if (~ p1 | ~ p4) begin
            { p5,  prop1 } <= {  prop1, ~ p4 };         //  q <= ~ _ps
            { p6, _prop1 } <= { _prop1, ~ p1 };         // _q <= ~ _pc
        end else if (~ lastt1 & p3) begin
            { p5,  prop1 } <= {  prop1,   d1 };         //  q <=   d
            { p6, _prop1 } <= { _prop1, ~ d1 };         // _q <= ~ d
        end else begin
            { p5,  prop1 } <= {  prop1,  prop1[0] };    //  q <=   q
            { p6, _prop1 } <= { _prop1, _prop1[0] };    // _q <=  _q
        end

        if (~ p13 | ~ p10) begin
            { p9,  prop2 } <= {  prop2, ~ p10 };        //  q <= ~ _ps
            { p8, _prop2 } <= { _prop2, ~ p13 };        // _q <= ~ _pc
        end else if (~ lastt2 & p11) begin
            { p9,  prop2 } <= {  prop2,   d2 };         //  q <=   d
            { p8, _prop2 } <= { _prop2, ~ d2 };         // _q <= ~ d
        end else begin
            { p9,  prop2 } <= {  prop2,  prop2[0] };    //  q <=   q
            { p8, _prop2 } <= { _prop2, _prop2[0] };    // _q <=  _q
        end

        { d1, setup1 } <= { setup1, p2  };
        { d2, setup2 } <= { setup2, p12 };

        lastt1 <= p3;
        lastt2 <= p11;
    end
endmodule

module X74LS75 (input yclock, zclock, zreset,
          output     p1     // _q0
        , input      p2     // d0
        , input      p3     // d1
        , input      p4     // e23
        , input      p5     // vcc
        , input      p6     // d2
        , input      p7     // d3
        , output     p8     // _q3
        , output reg p9     // q3
        , output reg p10    // q2
        , output     p11    // _q2
        , input      p12    // gnd
        , input      p13    // e01
        , output     p14    // _q1
        , output reg p15    // q1
        , output reg p16    // q0
);

    reg[3:0] aa, bb, cc, dd;

    assign p1  = ~ p16;
    assign p14 = ~ p15;
    assign p11 = ~ p10;
    assign p8  = ~ p9;

    always @(posedge zclock) begin
        { p16, aa } <= { aa, p13 ? p2 : aa[0] };
        { p15, bb } <= { bb, p13 ? p3 : bb[0] };
        { p10, cc } <= { cc, p4  ? p6 : cc[0] };
        { p9,  dd } <= { dd, p4  ? p7 : dd[0] };
    end
endmodule


module X74LS85 (input yclock, zclock, zreset,
          input  p1         // B3
        , input  p2         // (A < B) IN   from
        , input  p3         // (A = B) IN   lower
        , input  p4         // (A > B) IN   bits
        , output reg p5     // (A > B) OUT  to
        , output reg p6     // (A = B) OUT  higher
        , output reg p7     // (A < B) OUT  bits
        , input  p8         // GND
        , input  p9         // B0
        , input  p10        // A0
        , input  p11        // B1
        , input  p12        // A1
        , input  p13        // A2
        , input  p14        // B2
        , input  p15        // A3
        , input  p16        // VCC
);

    wire[3:0] a = { p15, p13, p12, p10 };
    wire[3:0] b = { p1,  p14, p11, p9  };

    reg[6:0] d5, d6, d7;

    wire agtb = (a >  b);
    wire aeqb = (a == b);
    wire altb = (a <  b);

    always @(posedge zclock) begin
        { p5, d5 } <= { d5, aeqb ? p4 : agtb };
        { p6, d6 } <= { d6, aeqb & p3 };
        { p7, d7 } <= { d7, aeqb ? p2 : altb };
    end
endmodule

module X74HC86 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , output reg p3
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , output reg p11
        , input  p12
        , input  p13
        , input  p14
);

    reg[3:0] aa, bb, cc, dd;

    always @(posedge zclock) begin
        { p3,  aa } <= { aa, p1  ^ p2  };
        { p6,  bb } <= { bb, p4  ^ p5  };
        { p8,  cc } <= { cc, p9  ^ p10 };
        { p11, dd } <= { dd, p12 ^ p13 };
    end
endmodule

module X74LS109 (input yclock, zclock, zreset,
          input  p1         // 1 _Pc
        , input  p2         // 1  J
        , input  p3         // 1 _K
        , input  p4         // 1  CLK
        , input  p5         // 1 _Ps
        , output reg p6     // 1  Q
        , output reg p7     // 1 _Q
        , input  p8         // GND
        , output reg p9     // 2 _Q
        , output reg p10    // 2  Q
        , input  p11        // 2 _Ps
        , input  p12        // 2  CLK
        , input  p13        // 2 _K
        , input  p14        // 2  J
        , input  p15        // 2 _Pc
        , input  p16        // VCC
);

    reg lastt1, lastt2;
    reg j1, k1, j2, k2;
    reg[2:0] jsetup1, ksetup1, jsetup2, ksetup2;
    reg[5:0] prop1, prop2, _prop1, _prop2;

    always @(posedge zclock) begin
        if (~ p1 | ~ p5) begin
            { p6,  prop1 } <= {  prop1, ~ p5 };     //  q <= ~ ps
            { p7, _prop1 } <= { _prop1, ~ p1 };     // _q <= ~ pc
        end else if (~ lastt1 & p4) begin
            if (~ j1 & ~ k1) begin                  // J=0 K=0
                { p6,  prop1 } <= {  prop1, p6   };
                { p7, _prop1 } <= { _prop1, p7   };
            end
            if (~ j1 &   k1) begin                  // J=0 K=1
                { p6,  prop1 } <= {  prop1, 1'b0 };
                { p7, _prop1 } <= { _prop1, 1'b1 };
            end
            if (  j1 & ~ k1) begin                  // J=1 K=0
                { p6,  prop1 } <= {  prop1, 1'b1 };
                { p7, _prop1 } <= { _prop1, 1'b0 };
            end
            if (  j1 &   k1) begin                  // J=1 K=1
                { p6,  prop1 } <= {  prop1, p7   };
                { p7, _prop1 } <= { _prop1, p6   };
            end
        end else begin
            { p6,  prop1 } <= {  prop1,  prop1[0] };
            { p7, _prop1 } <= { _prop1, _prop1[0] };
        end
        { j1, jsetup1 } <= { jsetup1,   p2 };
        { k1, ksetup1 } <= { ksetup1, ~ p3 };
        lastt1  <= p4;

        if (~ p15 | ~ p11) begin
            { p10, prop2 } <= {  prop2, ~ p11 };    //  q <= ~ ps
            { p9, _prop2 } <= { _prop2, ~ p15 };    // _q <= ~ pc
        end else if (~ lastt2 & p12) begin
            if (~ j2 & ~ k2) begin                  // J=0 K=0
                { p10, prop2 } <= {  prop2, p10  };
                { p9, _prop2 } <= { _prop2, p9   };
            end
            if (~ j2 &   k2) begin                  // J=0 K=1
                { p10, prop2 } <= {  prop2, 1'b0 };
                { p9, _prop2 } <= { _prop2, 1'b1 };
            end
            if (  j2 & ~ k2) begin                  // J=1 K=0
                { p10, prop2 } <= {  prop2, 1'b1 };
                { p9, _prop2 } <= { _prop2, 1'b0 };
            end
            if (  j2 &   k2) begin                  // J=1 K=1
                { p10, prop2 } <= {  prop2, p9   };
                { p9, _prop2 } <= { _prop2, p10  };
            end
        end else begin
            { p10, prop2 } <= {  prop2,  prop2[0] };
            { p9, _prop2 } <= { _prop2, _prop2[0] };
        end
        { j2, jsetup2 } <= { jsetup2,   p14 };
        { k2, ksetup2 } <= { ksetup2, ~ p13 };
        lastt2  <= p12;
    end
endmodule

module X74HC138 (input yclock, zclock, zreset,
          input      p1         // A2
        , input      p2         // A1
        , input      p3         // A0
        , input      p4         // _G0
        , input      p5         // _G1
        , input      p6         // G2
        , output reg p7         // Y7
        , input      p8         // GND
        , output     reg p9     // Y6
        , output     reg p10    // Y5
        , output     reg p11    // Y4
        , output     reg p12    // Y3
        , output     reg p13    // Y2
        , output     reg p14    // Y1
        , output     reg p15    // Y0
        , input      p16        // VCC
);

    wire g = ~ p4 & ~ p5 & p6;
    wire[2:0] n = { p3, p2, p1 };

    reg[4:0] d0, d1, d2, d3, d4, d5, d6, d7;

    always @(posedge zclock) begin
        { p15, d0 } <= { d0, ~ g | (n != 0) };
        { p14, d1 } <= { d1, ~ g | (n != 1) };
        { p13, d2 } <= { d2, ~ g | (n != 2) };
        { p12, d3 } <= { d3, ~ g | (n != 3) };
        { p11, d4 } <= { d4, ~ g | (n != 4) };
        { p10, d5 } <= { d5, ~ g | (n != 5) };
        { p9,  d6 } <= { d6, ~ g | (n != 6) };
        { p7,  d7 } <= { d7, ~ g | (n != 7) };
    end
endmodule

module X74LS139 (input yclock, zclock, zreset,
          input  p1     // 1 _E
        , input  p2     // 1 A0
        , input  p3     // 1 A1
        , output reg p4     // 1 _Y0
        , output reg p5     // 1 _Y1
        , output reg p6     // 1 _Y2
        , output reg p7     // 1 _Y3
        , input  p8     // GND
        , output reg p9     // 2 _Y3
        , output reg p10    // 2 _Y2
        , output reg p11    // 2 _Y1
        , output reg p12    // 2 _Y0
        , input  p13    // 2 A1
        , input  p14    // 2 A0
        , input  p15    // 2 _E
        , input  p16    // VCC
);

    wire[1:0] n1 = { p3,  p2  };
    wire[1:0] n2 = { p13, p14 };

    reg[5:0] d10, d11, d12, d13, d20, d21, d22, d23;

    always @(posedge zclock) begin
        { p4,  d10 } <= { d10, p1  | (n1 != 0) };
        { p5,  d11 } <= { d11, p1  | (n1 != 1) };
        { p6,  d12 } <= { d12, p1  | (n1 != 2) };
        { p7,  d13 } <= { d13, p1  | (n1 != 3) };

        { p12, d20 } <= { d20, p15 | (n2 != 0) };
        { p11, d21 } <= { d21, p15 | (n2 != 1) };
        { p10, d22 } <= { d22, p15 | (n2 != 2) };
        { p9,  d23 } <= { d23, p15 | (n2 != 3) };
    end
endmodule

module X74LS151 (input yclock, zclock, zreset,
          input  p1     // d3
        , input  p2     // d2
        , input  p3     // d1
        , input  p4     // d0
        , output reg p5 //  q
        , output     p6 // _q
        , input  p7     // _g
        , input  p8     // gnd
        , input  p9     // c (s2)
        , input  p10    // b (s1)
        , input  p11    // a (s0)
        , input  p12    // d7
        , input  p13    // d6
        , input  p14    // d5
        , input  p15    // d4
        , input  p16    // vcc
);

    wire[2:0] s = { p9, p10, p11 };
    assign p6 = ~ p5;

    reg[6:0] delay;

    always @(posedge zclock) begin
        { p5, delay } <= { delay,
                ~ p7  & ((s == 0) & p4  | (s == 1) & p3  | (s == 2) & p2  | (s == 3) & p1 |
                         (s == 4) & p15 | (s == 5) & p14 | (s == 6) & p13 | (s == 7) & p12) };
    end
endmodule

module X74LS153 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , input  p6
        , output reg p7
        , input  p8
        , output reg p9
        , input  p10
        , input  p11
        , input  p12
        , input  p13
        , input  p14
        , input  p15
        , input  p16
);

    wire[1:0] s = { p2, p14 };

    reg[5:0] dela, delb;

    always @(posedge zclock) begin
        { p7, dela } <= { dela, ~ p1  & ((s == 0) & p6  | (s == 1) & p5  | (s == 2) & p4  | (s == 3) & p3)  };
        { p9, delb } <= { delb, ~ p15 & ((s == 0) & p10 | (s == 1) & p11 | (s == 2) & p12 | (s == 3) & p13) };
    end
endmodule

module X74LS157 (input yclock, zclock, zreset,
          input  p1     // 0=A; 1=B
        , input  p2     // 1A
        , input  p3     // 1B
        , output reg p4     // 1Y
        , input  p5     // 2A
        , input  p6     // 2B
        , output reg p7     // 2Y
        , input  p8     // GND
        , output reg p9     // 3Y
        , input  p10    // 3B
        , input  p11    // 3A
        , output reg p12    // 4Y
        , input  p13    // 4B
        , input  p14    // 4A
        , input  p15    // _G
        , input  p16    // VCC
);

    reg[3:0] dela, delb, delc, deld;

    always @(posedge zclock) begin
        { p4,  dela } <= { dela, ~ p15 & (p1 ? p3  : p2)  };
        { p7,  delb } <= { delb, ~ p15 & (p1 ? p6  : p5)  };
        { p9,  delc } <= { delc, ~ p15 & (p1 ? p10 : p11) };
        { p12, deld } <= { deld, ~ p15 & (p1 ? p13 : p14) };
    end
endmodule

module X74LS161 (input yclock, zclock, zreset,
          input      p1     // _clr
        , input      p2     // clk
        , input      p3     // a
        , input      p4     // b
        , input      p5     // c
        , input      p6     // d
        , input      p7     // enp
        , input      p8     // gnd
        , input      p9     // _load
        , input      p10    // ent
        , output reg p11    // qd
        , output reg p12    // qc
        , output reg p13    // qb
        , output reg p14    // qa
        , output     p15    // rco
        , input      p16    // vcc
);

    assign p15 = p14 & p13 & p12 & p11 & p10;

    reg lastt;

    reg[27:00] delay;

    always @(posedge zclock) begin
        if (~ p1) begin
            { p11, p12, p13, p14, delay } <= { delay[27:16], 20'b0 };
        end else if (~ lastt & p2) begin
            ////$display ("74LS161*: %m load=%b inc=%b q=%b%b%b%b", ~ p9, p7 & p10, p11, p12, p13, p14);
            if (~ p9) begin
                { p11, p12, p13, p14, delay } <= { delay, p6, p5, p4, p3 };
            end else if (p7 & p10) begin
                { p11, p12, p13, p14, delay } <= { delay, { p11, p12, p13, p14 } + 4'b0001 };
            end else begin
                { p11, p12, p13, p14, delay } <= { delay, p11, p12, p13, p14 };
            end
        end else begin
            { p11, p12, p13, p14, delay } <= { delay, delay[03:00] };
        end

        lastt <= p2;
    end
endmodule

module X74LS174 (input yclock, zclock, zreset,
          input      p1
        , output reg p2
        , input      p3
        , input      p4
        , output reg p5
        , input      p6
        , output reg p7
        , input      p8
        , input      p9
        , output reg p10
        , input      p11
        , output reg p12
        , input      p13
        , input      p14
        , output reg p15
        , input      p16
);

    reg lastt;

    reg da, db, dc, dd, de, df;
    reg[1:0] sa, sb, sc, sd, se, sf;    // setup delays
    reg[4:0] pa, pb, pc, pd, pe, pf;    // prop delays

    always @(posedge zclock) begin
        if (~ p1) begin
            { p2,  pa } <= { pa, 1'b0  };
            { p5,  pb } <= { pb, 1'b0  };
            { p7,  pc } <= { pc, 1'b0  };
            { p10, pd } <= { pd, 1'b0  };
            { p12, pe } <= { pe, 1'b0  };
            { p15, pf } <= { pf, 1'b0  };
        end else if (~ lastt & p9) begin
            { p2,  pa } <= { pa, da };
            { p5,  pb } <= { pb, db };
            { p7,  pc } <= { pc, dc };
            { p10, pd } <= { pd, dd };
            { p12, pe } <= { pe, de };
            { p15, pf } <= { pf, df };
        end else begin
            { p2,  pa } <= { pa, pa[0] };
            { p5,  pb } <= { pb, pb[0] };
            { p7,  pc } <= { pc, pc[0] };
            { p10, pd } <= { pd, pd[0] };
            { p12, pe } <= { pe, pe[0] };
            { p15, pf } <= { pf, pf[0] };
        end

        { da, sa } <= { sa, p3  };
        { db, sb } <= { sb, p4  };
        { dc, sc } <= { sc, p6  };
        { dd, sd } <= { sd, p11 };
        { de, se } <= { se, p13 };
        { df, sf } <= { sf, p14 };

        lastt <= p9;
    end

endmodule

module X74LS175 (input yclock, zclock, zreset,
          input      p1
        , output reg p2
        , output     p3
        , input      p4
        , input      p5
        , output     p6
        , output reg p7
        , input      p8
        , input      p9
        , output reg p10
        , output     p11
        , input      p12
        , input      p13
        , output     p14
        , output reg p15
        , input      p16
);

    assign p3  = ~ p2;
    assign p6  = ~ p7;
    assign p11 = ~ p10;
    assign p14 = ~ p15;

    reg lastt;

    reg da, db, dc, dd;
    reg[1:0] sa, sb, sc, sd;    // setup delays
    reg[4:0] pa, pb, pc, pd;    // prop delays

    always @(posedge zclock) begin
        if (~ p1) begin
            { p2,  pa } <= { pa, 1'b0 };
            { p7,  pb } <= { pb, 1'b0 };
            { p10, pc } <= { pc, 1'b0 };
            { p15, pd } <= { pd, 1'b0 };
        end else if (~ lastt & p9) begin
            { p2,  pa } <= { pa, da };
            { p7,  pb } <= { pb, db };
            { p10, pc } <= { pc, dc };
            { p15, pd } <= { pd, dd };
        end else begin
            { p2,  pa } <= { pa, pa[0] };
            { p7,  pb } <= { pb, pb[0] };
            { p10, pc } <= { pc, pc[0] };
            { p15, pd } <= { pd, pd[0] };
        end

        { da, sa } <= { sa, p4  };
        { db, sb } <= { sb, p5  };
        { dc, sc } <= { sc, p12 };
        { dd, sd } <= { sd, p13 };

        lastt <= p9;
    end

endmodule

module X74LS193 (input yclock, zclock, zreset,
          input      p1     // db
        , output     p2     // qb
        , output     p3     // qa
        , input      p4     // _dn
        , input      p5     // _up
        , output     p6     // qc
        , output     p7     // qd
        , input      p8     // gnd
        , input      p9     // dd
        , input      p10    // dc
        , input      p11    // _ld
        , output reg p12    // _co
        , output reg p13    // _bo
        , input      p14    // clr
        , input      p15    // da
        , input      p16    // vcc
);

    reg[35:00] delay;
    reg[5:0] bodel, codel;

    wire  da = p15;
    wire  db = p1;
    wire  dc = p10;
    wire  dd = p9;
    wire _dn = p4;
    wire _up = p5;
    wire _ld = p11;
    wire clr = p14;

    reg _lastdn, _lastup;
    reg qa, qb, qc, qd;
    assign p3 = qa;
    assign p2 = qb;
    assign p6 = qc;
    assign p6 = qd;

    always @(posedge zclock) begin
        if (clr) begin
            // async clear takes 48nS max
            { qd, qc, qb, qa, delay } <= { delay, 4'b0 };
        end else if (~ _ld) begin
            // async load takes 52nS max
            { qd, qc, qb, qa, delay } <= { delay, dd, dc, db, da };
        end else begin
            if (_up & _dn) begin
                // clock up and down at the same time
                if (~ _lastdn & ~ _lastup) begin
                    { qd, qc, qb, qa, delay } <= { delay,   qd, qc, qb, qa };
                end
                // clock down takes 50nS max
                if (~ _lastdn &   _lastup) begin
                    { qd, qc, qb, qa, delay } <= { delay, { qd, qc, qb, qa } - 4'b1 };
                end
                // clock up takes 50nS max
                if (  _lastdn & ~ _lastup) begin
                    { qd, qc, qb, qa, delay } <= { delay, { qd, qc, qb, qa } + 4'b1 };
                end
                // clock neither, just advance delay
                if (  _lastdn &   _lastup) begin
                    { qd, qc, qb, qa, delay } <= { delay, delay[3:0] };
                end
            end else begin
                // getting ready to clock, just advance delay
                { qd, qc, qb, qa, delay } <= { delay, delay[3:0] };
            end
        end

        // carry out and borrow out takes 33nS delay
        { p12, codel } <= { codel, ~ (  qa &   qb &   qc &   qd & ~ _up) };
        { p13, bodel } <= { bodel, ~ (~ qa & ~ qb & ~ qc & ~ qd & ~ _dn) };

        // detect count up/down edges
        _lastdn <= _dn;
        _lastup <= _up;
    end
endmodule

module X74HC240 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p3i
        , output reg p3o
        , input      p4
        , input      p5i
        , output reg p5o
        , input      p6
        , input      p7i
        , output reg p7o
        , input      p8
        , input      p9i
        , output reg p9o
        , input      p10
        , input      p11
        , input      p12i
        , output reg p12o
        , input      p13
        , input      p14i
        , output reg p14o
        , input      p15
        , input      p16i
        , output reg p16o
        , input      p17
        , input      p18i
        , output reg p18o
        , input      p19
        , input      p20
);

    reg[11:00] del1, del2;

    always @(posedge zclock) begin
        // 1y3   1y2   1y1   1y0                     1oe              1a3  1a2  1a1  1a0
        { p12o, p14o, p16o, p18o, del1 } <= { del1, (p1  ? 4'hF : ~ { p8,  p6,  p4,  p2  }) };

        // 2y3   2y2   2y1   2y0                     2oe              2a3  2a2  2a1  2a0
        {  p3o,  p5o,  p7o,  p9o, del2 } <= { del2, (p19 ? 4'hF : ~ { p17, p15, p13, p11 }) };
    end
endmodule

module X74HC244 (input yclock, zclock, zreset,
          input      p1
        , input      p2
        , input      p3i
        , output reg p3o
        , input      p4
        , input      p5i
        , output reg p5o
        , input      p6
        , input      p7i
        , output reg p7o
        , input      p8
        , input      p9i
        , output reg p9o
        , input      p10
        , input      p11
        , input      p12i
        , output reg p12o
        , input      p13
        , input      p14i
        , output reg p14o
        , input      p15
        , input      p16i
        , output reg p16o
        , input      p17
        , input      p18i
        , output reg p18o
        , input      p19
        , input      p20
);

    reg[11:00] del1, del2;

    always @(posedge zclock) begin
        // 1y3   1y2   1y1   1y0                    1oe            1a3  1a2  1a1  1a0
        { p12o, p14o, p16o, p18o, del1 } <= { del1, p1  ? 4'hF : { p8,  p6,  p4,  p2  } };

        // 2y3   2y2   2y1   2y0                    2oe            2a3  2a2  2a1  2a0
        {  p3o,  p5o,  p7o,  p9o, del2 } <= { del2, p19 ? 4'hF : { p17, p15, p13, p11 } };
    end
endmodule

module X74LS283 (input yclock, zclock, zreset,
          output reg p1
        , input  p2
        , input  p3
        , output reg p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , output reg p9
        , output reg p10
        , input  p11
        , input  p12
        , output reg p13
        , input  p14
        , input  p15
        , input  p16
);

    reg c0, c1, c2;
    reg[1:0] x0, x1a, x1b, x2, x3;

    always @(posedge zclock) begin
        x0          <= { 1'b0, p5  } + { 1'b0, p6  } + { 1'b0, p7 };
        { c0, p4  } <= x0;
        x1a         <= { 1'b0, p3  } + { 1'b0, p2  } + { 1'b0, c0 };
        x1b         <= x1a;
        { c1, p1  } <= x1b;
        x2          <= { 1'b0, p14 } + { 1'b0, p15 } + { 1'b0, c1 };
        { c2, p13 } <= x2;
        x3          <= { 1'b0, p12 } + { 1'b0, p11 } + { 1'b0, c2 };
        { p9, p10 } <= x3;
    end
endmodule

module X74LS540 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , input  p9
        , input  p10
        , input  p11i
        , output reg p11o
        , input  p12i
        , output reg p12o
        , input  p13i
        , output reg p13o
        , input  p14i
        , output reg p14o
        , input  p15i
        , output reg p15o
        , input  p16i
        , output reg p16o
        , input  p17i
        , output reg p17o
        , input  p18i
        , output reg p18o
        , input  p19
        , input  p20
);

    reg[23:00] delay;

    wire oe = ~ p1 & ~ p19;
    wire[7:0] din = { p9, p8, p7, p6, p5, p4, p3, p2 };

    always @(posedge zclock) begin
        { p11o, p12o, p13o, p14o, p15o, p16o, p17o, p18o, delay } <= { delay, oe ? ~ din : 8'hFF };
    end
endmodule

module X74HCT541 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , input  p9
        , input  p10
        , input  p11i
        , output reg p11o
        , input  p12i
        , output reg p12o
        , input  p13i
        , output reg p13o
        , input  p14i
        , output reg p14o
        , input  p15i
        , output reg p15o
        , input  p16i
        , output reg p16o
        , input  p17i
        , output reg p17o
        , input  p18i
        , output reg p18o
        , input  p19
        , input  p20
);

    reg[23:00] delay;

    wire oe = ~ p1 & ~ p19;
    wire[7:0] din = { p9, p8, p7, p6, p5, p4, p3, p2 };

    always @(posedge zclock) begin
        { p11o, p12o, p13o, p14o, p15o, p16o, p17o, p18o, delay } <= { delay, oe ? din : 8'hFF };
    end

endmodule

module X74HC4075 (input yclock, zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , input  p8
        , output reg p9
        , output reg p10
        , input  p11
        , input  p12
        , input  p13
        , input  p14
);

    reg[2:0] aa, bb, cc;

    always @(posedge zclock) begin
        { p6,  aa } <= { aa, p3  | p4  | p5  };
        { p9,  bb } <= { bb, p1  | p2  | p8  };
        { p10, cc } <= { cc, p13 | p12 | p11 };
    end

endmodule

module XCY7C199 (input yclock, zclock, zreset,
    input      p1,   // A5
    input      p2,   // A6
    input      p3,   // A7
    input      p4,   // A8
    input      p5,   // A9
    input      p6,   // A10
    input      p7,   // A11
    input      p8,   // A12
    input      p9,   // A13
    input      p10,  // A14
    input      p11i, // IO0
    output reg p11o, // IO0
    input      p12i, // IO1
    output reg p12o, // IO1
    input      p13i, // IO2
    output reg p13o, // IO2
    input      p14,  // GND
    input      p15i, // IO3
    output reg p15o, // IO3
    input      p16i, // IO4
    output reg p16o, // IO4
    input      p17i, // IO5
    output reg p17o, // IO5
    input      p18i, // IO6
    output reg p18o, // IO6
    input      p19i, // IO7
    output reg p19o, // IO7
    input      p20,  // _CE
    input      p21,  // A0
    input      p22,  // _OE
    input      p23,  // A1
    input      p24,  // A2
    input      p25,  // A3
    input      p26,  // A4
    input      p27,  // _WE
    input      p28   // VCC
);

    wire[14:00] a = { p10, p9, p8, p7, p6, p5, p4, p3, p2, p1, p26, p25, p24, p23, p21 };
    wire[7:0] din = { p19i, p18i, p17i, p16i, p15i, p13i, p12i, p11i };
    reg[7:0] array[32767:0];
    reg[31:00] delay;
    reg[1:0] delce, deloe, delwe;
    reg ce, oe, we;

    always @(posedge zclock) begin
        { ce, delce } <= { delce, ~ p20 };
        { oe, deloe } <= { deloe, ~ p22 };
        { we, delwe } <= { delwe, ~ p27 };
        if (ce & we) begin
            ////$display ("XCY7C199*: writing array[%o] <= %o", a, delay[31:24]);
            array[a] <= delay[31:24];
            delay    <= { delay[23:00], din };
        end else begin
            ////$display ("XCY7C199*: reading array[%o] => %o", a, array[a]);
            delay    <= { delay[23:00], array[a] };
        end
        { p19o, p18o, p17o, p16o, p15o, p13o, p12o, p11o } <= (ce & oe & ~ we) ? delay[31:24] : 8'hFF;
    end
endmodule

module X10MHz (input yclock, zclock, zreset,
        input  p1,  // INPUT
        input  p7,  // POWERIN
        output p8,  // OUTPUT
        input  p14  // POWERIN
    );

    assign p8 = yclock; // this wires yclock to clok2
endmodule

module XMCP23017_SP (input yclock, zclock, zreset,
        input  p1i,     // GPB0
        output p1o,
        input  p2i,     // GPB1
        output p2o,
        input  p3i,     // GPB2
        output p3o,
        input  p4i,     // GPB3
        output p4o,
        input  p5i,     // GPB4
        output p5o,
        input  p6i,     // GPB5
        output p6o,
        input  p7i,     // GPB6
        output p7o,
        input  p8i,     // GPB7
        output p8o,
        input  p9,      // VDD
        input  p10,     // VSS
        input  p11,     // NC
        input  p12,     // SCK
        input  p13i,    // SDA
        output p13o,
        input  p14,     // NC
        input  p15,     // A0
        input  p16,     // A1
        input  p17,     // A2
        input  p18,     // _RESET
        input  p19i,    // INTB
        output p19o,
        input  p20i,    // INTA
        output p20o,
        input  p21i,    // GPA0
        output p21o,
        input  p22i,    // GPA1
        output p22o,
        input  p23i,    // GPA2
        output p23o,
        input  p24i,    // GPA3
        output p24o,
        input  p25i,    // GPA4
        output p25o,
        input  p26i,    // GPA5
        output p26o,
        input  p27i,    // GPA6
        output p27o,
        input  p28i,    // GPA7
        output p28o
    );

    mcp23017 wrap23017 (
        .adr   ({ p17, p16, p15 }),
        .clk   (zclock),
        .res   (~ p18),
        .scl   (p12),
        .sdai  (p13i),
        .sdao  (p13o),
        .adefs (8'hFF),
        .bdefs (8'hFF),
        .ainps ({ p28i,p27i,p26i,p25i,p24i,p23i,p22i,p21i }),
        .binps ({ p8i, p7i, p6i, p5i, p4i, p3i, p2i, p1i  }),
        .aouts ({ p28o,p27o,p26o,p25o,p24o,p23o,p22o,p21o }),
        .bouts ({ p8o, p7o, p6o, p5o, p4o, p3o, p2o, p1o  })
    );

endmodule

module X47K (input yclock, zclock, input zreset, input p1, input p2);
endmodule
