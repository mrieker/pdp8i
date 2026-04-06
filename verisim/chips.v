
module X74HC00 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p3  <= ~ (p1  & p2);
        p6  <= ~ (p4  & p5);
        p8  <= ~ (p9  & p10);
        p11 <= ~ (p12 & p13);
    end

endmodule

module X74LS00 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p3  <= ~ (p1  & p2);
        p6  <= ~ (p4  & p5);
        p8  <= ~ (p9  & p10);
        p11 <= ~ (p12 & p13);
    end

endmodule

module X74HC02 (input zclock, zreset,
          output reg p1
        , input  p2
        , input  p3
        , output reg p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , input  p9
        , output reg p10
        , input  p11
        , input  p12
        , output reg p13
        , input  p14
);

    always @(posedge zclock) begin
        p1  <= ~ (p2  | p3);
        p4  <= ~ (p5  | p6);
        p10 <= ~ (p8  | p9);
        p13 <= ~ (p11 | p12);
    end

endmodule

module X74LS02 (input zclock, zreset,
          output reg p1
        , input  p2
        , input  p3
        , output reg p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , input  p9
        , output reg p10
        , input  p11
        , input  p12
        , output reg p13
        , input  p14
);

    always @(posedge zclock) begin
        p1  <= ~ (p2  | p3);
        p4  <= ~ (p5  | p6);
        p10 <= ~ (p8  | p9);
        p13 <= ~ (p11 | p12);
    end

endmodule

module X74HC04 (input zclock, zreset,
          input  p1
        , output reg p2
        , input  p3
        , output reg p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , output reg p10
        , input  p11
        , output reg p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p2  <= ~ p1;
        p4  <= ~ p3;
        p6  <= ~ p5;
        p8  <= ~ p9;
        p10 <= ~ p11;
        p12 <= ~ p13;
    end

endmodule

module X74LS04 (input zclock, zreset,
          input  p1
        , output reg p2
        , input  p3
        , output reg p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , output reg p10
        , input  p11
        , output reg p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p2  <= ~ p1;
        p4  <= ~ p3;
        p6  <= ~ p5;
        p8  <= ~ p9;
        p10 <= ~ p11;
        p12 <= ~ p13;
    end

endmodule

module X74LS08 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p3  <= p1  & p2;
        p6  <= p4  & p5;
        p8  <= p9  & p10;
        p11 <= p12 & p13;
    end

endmodule

module X74LS10 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , input  p11
        , output reg p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p6  <= ~ (p3 & p4  & p5);
        p8  <= ~ (p9 & p10 & p11);
        p12 <= ~ (p1 & p2  & p13);
    end

endmodule

module X74LS11 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , input  p11
        , output reg p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p6  <= p3 & p4  & p5;
        p8  <= p9 & p10 & p11;
        p12 <= p1 & p2  & p13;
    end

endmodule

module X74LS20 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , input  p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p6  <= ~ (p1 & p2  & p4  & p5);
        p8  <= ~ (p9 & p10 & p12 & p13);
    end

endmodule

module X74LS21 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , input  p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p6 <= p1 & p2  & p4  & p5;
        p8 <= p9 & p10 & p12 & p13;
    end

endmodule

module X74HC27 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , input  p11
        , output reg p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p6  <= ~ (p3 | p4  | p5);
        p8  <= ~ (p9 | p10 | p11);
        p12 <= ~ (p1 | p2  | p13);
    end

endmodule

module X74LS27 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output reg p6
        , input  p7
        , output reg p8
        , input  p9
        , input  p10
        , input  p11
        , output reg p12
        , input  p13
        , input  p14
);

    always @(posedge zclock) begin
        p6  <= ~ (p3 | p4  | p5);
        p8  <= ~ (p9 | p10 | p11);
        p12 <= ~ (p1 | p2  | p13);
    end

endmodule

module X74LS30 (input zclock, zreset,
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , input  p6
        , input  p7
        , output reg p8
        , input  p11
        , input  p12
        , input  p14
);

    always @(posedge zclock) begin
        p8 <= ~ (p1 & p2 & p3 & p4 & p5 & p6 & p11 & p12);
    end

endmodule

module X74LS32 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p3  <= p1  | p2;
        p6  <= p4  | p5;
        p8  <= p9  | p10;
        p11 <= p12 | p13;
    end

endmodule

module X74LS42 (input zclock, zreset,
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

    wire[3:0] n = { p12, p13, p14, p15 };

    always @(posedge zclock) begin
        p1  <= (n != 0);
        p2  <= (n != 1);
        p3  <= (n != 2);
        p4  <= (n != 3);
        p5  <= (n != 4);
        p6  <= (n != 5);
        p7  <= (n != 6);
        p9  <= (n != 7);
        p10 <= (n != 8);
        p11 <= (n != 9);
    end

endmodule

module X74HC74 (input zclock, zreset,
          input  p1         // 1 _pc
        , input  p2         // 1 D
        , input  p3         // 1 T
        , input  p4         // 1 _ps
        , output reg p5     // 1 Q
        , output reg p6     // 1 _Q
        , input  p7         // GND
        , output reg p8     // 2 _Q
        , output reg p9     // 2 Q
        , input  p10        // 2 _ps
        , input  p11        // 2 T
        , input  p12        // 2 D
        , input  p13        // 2 _pc
        , input  p14        // VCC
);

    reg lastt1, lastt2;

    always @(posedge zclock) begin
        if (~ p1 | ~ p4) begin
            p5 <= ~ p4;     //  q <= ~ _ps
            p6 <= ~ p1;     // _q <= ~ _pc
        end else if (~ lastt1 & p3) begin
            p5 <=   p2;     //  q <=   d
            p6 <= ~ p2;     // _q <= ~ d
        end

        if (~ p13 | ~ p10) begin
            p9 <= ~ p10;    //  q <= ~ _ps
            p8 <= ~ p13;    // _q <= ~ _pc
        end else if (~ lastt2 & p11) begin
            p9 <=   p12;    //  q <=   d
            p8 <= ~ p12;    // _q <= ~ d
        end

        lastt1 <= p3;
        lastt2 <= p11;
    end

endmodule

module X74LS85 (input zclock, zreset,
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

    reg[2:0] d5, d6, d7;

    wire agtb = (a >  b);
    wire aeqb = (a == b);
    wire altb = (a <  b);

    always @(posedge zclock) begin
        { p5, d5 } <= { d5, aeqb ? p4 : agtb };
        { p6, d6 } <= { d6, aeqb & p3 };
        { p7, d7 } <= { d7, aeqb ? p2 : altb };
    end

endmodule

module X74HC86 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p3  <= p1  ^ p2;
        p6  <= p4  ^ p5;
        p8  <= p9  ^ p10;
        p11 <= p12 ^ p13;
    end

endmodule

module X74LS109 (input zclock, zreset,
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

    always @(posedge zclock) begin
        if (~ p1 | ~ p5) begin
            p6  <= ~ p5;    //  q <= ~ ps
            p7  <= ~ p1;    // _q <= ~ pc
        end else if (~ lastt1 & p4) begin
            if (  p2 &   p3) begin  // J=1 K=0
                p6 <= 1;
                p7 <= 0;
            end
            if (  p2 & ~ p3) begin  // J=1 K=1
                p6 <= p7;
                p7 <= p6;
            end
            if (~ p2 & ~ p3) begin  // J=0 K=1
                p6 <= 0;
                p7 <= 1;
            end
        end

        if (~ p15 | ~ p11) begin
            p10 <= ~ p11;   //  q <= ~ ps
            p9  <= ~ p15;   // _q <= ~ pc
        end else if (~ lastt2 & p12) begin
            if ( p14 &  p13) begin  // J=1 K=0
                p10 <= 1;
                p9  <= 0;
            end
            if ( p14 & ~p13) begin  // J=1 K=1
                p10 <= p9;
                p9  <= p10;
            end
            if (~p14 & ~p13) begin  // J=0 K=1
                p10 <= 0;
                p9  <= 1;
            end
        end

        lastt1 <= p4;
        lastt2 <= p12;
    end

endmodule

module X74HC138 (input zclock, zreset,
          input  p1     // A2
        , input  p2     // A1
        , input  p3     // A0
        , input  p4     // _G0
        , input  p5     // _G1
        , input  p6     // G2
        , output reg p7     // Y7
        , input  p8     // GND
        , output reg p9     // Y6
        , output reg p10    // Y5
        , output reg p11    // Y4
        , output reg p12    // Y3
        , output reg p13    // Y2
        , output reg p14    // Y1
        , output reg p15    // Y0
        , input  p16    // VCC
);

    wire g = ~ p4 & ~ p5 & p6;
    wire[2:0] n = { p3, p2, p1 };

    always @(posedge zclock) begin
        p15 <= ~ g | (n != 0);
        p14 <= ~ g | (n != 1);
        p13 <= ~ g | (n != 2);
        p12 <= ~ g | (n != 3);
        p11 <= ~ g | (n != 4);
        p10 <= ~ g | (n != 5);
        p9  <= ~ g | (n != 6);
        p7  <= ~ g | (n != 7);
    end

endmodule

module X74LS139 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p4  <= p1  | (n1 != 0);
        p5  <= p1  | (n1 != 1);
        p6  <= p1  | (n1 != 2);
        p7  <= p1  | (n1 != 3);

        p12 <= p15 | (n2 != 0);
        p11 <= p15 | (n2 != 1);
        p10 <= p15 | (n2 != 2);
        p9  <= p15 | (n2 != 3);
    end

endmodule

module X74LS151 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p5 <= ~ p7  & ((s == 0) & p4  | (s == 1) & p3  | (s == 2) & p2  | (s == 3) & p1 |
                       (s == 4) & p15 | (s == 5) & p14 | (s == 6) & p13 | (s == 7) & p12);
    end

endmodule

module X74LS153 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p7 <= ~ p1  & ((s == 0) & p6  | (s == 1) & p5  | (s == 2) & p4  | (s == 3) & p3);
        p9 <= ~ p15 & ((s == 0) & p10 | (s == 1) & p11 | (s == 2) & p12 | (s == 3) & p13);
    end

endmodule

module X74LS157 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p4  <= ~ p15 & (p1 ? p3  : p2);
        p7  <= ~ p15 & (p1 ? p6  : p5);
        p9  <= ~ p15 & (p1 ? p10 : p11);
        p12 <= ~ p15 & (p1 ? p13 : p14);
    end

endmodule

module X74LS161 (input zclock, zreset,
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

    always @(posedge zclock) begin
        if (~ p1) begin
            { p11, p12, p13, p14 } <= 0;
        end else if (~ lastt & p2) begin
            if (~ p9) begin
                { p11, p12, p13, p14 } <= { p6, p5, p4, p3 };
            end else if (p7 & p10) begin
                { p11, p12, p13, p14 } <= { p11, p12, p13, p14 } + 1;
            end
        end

        lastt <= p2;
    end

endmodule

module X74LS174 (input zclock, zreset,
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

    always @(posedge zclock) begin
        if (~ p1) begin
            p2  <= 0;
            p5  <= 0;
            p7  <= 0;
            p10 <= 0;
            p12 <= 0;
            p15 <= 0;
        end else if (~ lastt & p9) begin
            p2  <= p3;
            p5  <= p4;
            p7  <= p6;
            p10 <= p11;
            p12 <= p13;
            p15 <= p14;
        end

        lastt <= p9;
    end

endmodule

module Z74LS174 (input zclock, zreset,
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

    always @(posedge zclock) begin
        $display ("Z74LS174*: %m _PC=%b T=%b D=%o Q=%o", p1, p9, {p14,p13,p11,p6,p4,p3}, {p15,p12,p10,p7,p5,p2});
        if (~ p1) begin
            p2  <= 0;
            p5  <= 0;
            p7  <= 0;
            p10 <= 0;
            p12 <= 0;
            p15 <= 0;
        end else if (~ lastt & p9) begin
            p2  <= p3;
            p5  <= p4;
            p7  <= p6;
            p10 <= p11;
            p12 <= p13;
            p15 <= p14;
        end

        lastt <= p9;
    end

endmodule

module X74LS175 (input zclock, zreset,
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

    always @(posedge zclock) begin
        if (~ p1) begin
            p2  <= 0;
            p7  <= 0;
            p10 <= 0;
            p15 <= 0;
        end else if (~ lastt & p9) begin
            p2  <= p4;
            p7  <= p5;
            p10 <= p12;
            p15 <= p13;
        end

        lastt <= p9;
    end

endmodule

module X74HC240 (input zclock, zreset,
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

    always @(posedge zclock) begin
        // 1y3   1y2   1y1   1y0      1oe              1a3  1a2  1a1  1a0
        { p12o, p14o, p16o, p18o } <= p1  ? 4'h0 : ~ { p8,  p6,  p4,  p2  };

        // 2y3   2y2   2y1   2y0      2oe              2a3  2a2  2a1  2a0
        {  p3o,  p5o,  p7o,  p9o } <= p19 ? 4'h0 : ~ { p17, p15, p13, p11 };
    end

endmodule

module X74LS283 (input zclock, zreset,
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

    always @(posedge zclock) begin
        { c0, p4  } <= { 1'b0, p5  } + { 1'b0, p6  } + { 1'b0, p7 };
        { c1, p1  } <= { 1'b0, p3  } + { 1'b0, p2  } + { 1'b0, c0 };
        { c2, p13 } <= { 1'b0, p14 } + { 1'b0, p15 } + { 1'b0, c1 };
        { p9, p10 } <= { 1'b0, p12 } + { 1'b0, p11 } + { 1'b0, c2 };
    end

endmodule

module X74LS540 (input zclock, zreset,
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

    wire oe = ~ p1 & ~ p19;
    wire[7:0] din = { p9, p8, p7, p6, p5, p4, p3, p2 };

    always @(posedge zclock) begin
        { p11o, p12o, p13o, p14o, p15o, p16o, p17o, p18o } <= oe ? ~ din : 8'h00;
    end

endmodule

module X74HCT541 (input zclock, zreset,
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

    wire oe = ~ p1 & ~ p19;
    wire[7:0] din = { p9, p8, p7, p6, p5, p4, p3, p2 };

    always @(posedge zclock) begin
        { p11o, p12o, p13o, p14o, p15o, p16o, p17o, p18o } <= oe ? din : 8'h00;
    end

endmodule

module X74HC4075 (input zclock, zreset,
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

    always @(posedge zclock) begin
        p6  <= p3  | p4  | p5;
        p9  <= p1  | p2  | p8;
        p10 <= p13 | p12 | p11;
    end

endmodule

module XCY7C199 (input zclock, zreset,
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
    reg[7:0] array[32767:0], delay;

    always @(posedge zclock) begin
        if (~ p20 & ~ p27) begin
            array[a] <= din;
            delay <= din;
        end else begin
            delay <= array[a];
        end
        { p19o, p18o, p17o, p16o, p15o, p13o, p12o, p11o } <= (~ p20 & ~ p22 & p27) ? delay : 8'h00;
    end

endmodule

module X10MHz (
        input  zclock,
        input  zreset,
        input      p1,  // INPUT
        input      p7,  // POWERIN
        output reg p8,  // OUTPUT
        input      p14  // POWERIN
    );

    reg[3:0] div;

    always @(posedge zclock or posedge zreset) begin
        if (zreset) begin
            div <= 0;
            p8  <= 0;
        end else if (div == 4) begin
            div <= 0;
            p8  <= ~ p8;
        end else begin
            div <= div + 1;
        end
    end

endmodule

module XMCP23017_SP (
        input  zclock,
        input  zreset,
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
        .adefs (8'hC0),
        .bdefs (8'hC0),
        .ainps ({ p28i,p27i,p26i,p25i,p24i,p23i,p22i,p21i }),
        .binps ({ p8i, p7i, p6i, p5i, p4i, p3i, p2i, p1i  }),
        .aouts ({ p28o,p27o,p26o,p25o,p24o,p23o,p22o,p21o }),
        .bouts ({ p8o, p7o, p6o, p5o, p4o, p3o, p2o, p1o  })
    );

endmodule

module X47K (input zclock, input zreset, input p1, input p2);
endmodule
