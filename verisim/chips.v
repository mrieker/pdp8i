
module X74HC00 (
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

    assign p3  = ~ (p1  & p2);
    assign p6  = ~ (p4  & p5);
    assign p8  = ~ (p9  & p10);
    assign p11 = ~ (p12 & p13);

endmodule

module X74LS00 (
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

    assign p3  = ~ (p1  & p2);
    assign p6  = ~ (p4  & p5);
    assign p8  = ~ (p9  & p10);
    assign p11 = ~ (p12 & p13);

endmodule

module X74HC02 (
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

    assign p1  = ~ (p2  | p3);
    assign p4  = ~ (p5  | p6);
    assign p10 = ~ (p8  | p9);
    assign p13 = ~ (p11 | p12);

endmodule

module X74LS02 (
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

    assign p1  = ~ (p2  | p3);
    assign p4  = ~ (p5  | p6);
    assign p10 = ~ (p8  | p9);
    assign p13 = ~ (p11 | p12);

endmodule

module X74HC04 (
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

    assign p2  = ~ p1;
    assign p4  = ~ p3;
    assign p6  = ~ p5;
    assign p8  = ~ p9;
    assign p10 = ~ p11;
    assign p12 = ~ p13;

endmodule

module X74LS04 (
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

    assign p2  = ~ p1;
    assign p4  = ~ p3;
    assign p6  = ~ p5;
    assign p8  = ~ p9;
    assign p10 = ~ p11;
    assign p12 = ~ p13;

endmodule

module X74LS08 (
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

    assign p3  = p1  & p2;
    assign p6  = p4  & p5;
    assign p8  = p9  & p10;
    assign p11 = p12 & p13;

endmodule

module X74LS10 (
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

    assign p6  = ~ (p3 & p4  & p5);
    assign p8  = ~ (p9 & p10 & p11);
    assign p12 = ~ (p1 & p2  & p13);

endmodule

module X74LS11 (
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

    assign p6  = p3 & p4  & p5;
    assign p8  = p9 & p10 & p11;
    assign p12 = p1 & p2  & p13;

endmodule

module X74LS20 (
          input  p1
        , input  p2
        , input  p4
        , input  p5
        , output p6
        , input  p7
        , output p8
        , input  p9
        , input  p10
        , input  p12
        , input  p13
        , input  p14
);

    assign p6  = ~ (p1 & p2  & p4  & p5);
    assign p8  = ~ (p9 & p10 & p12 & p13);

endmodule

module X74LS21 (
          input  p1
        , input  p2
        , input  p4
        , input  p5
        , output p6
        , input  p7
        , output p8
        , input  p9
        , input  p10
        , input  p12
        , input  p13
        , input  p14
);

    assign p6  = p1 & p2  & p4  & p5;
    assign p8  = p9 & p10 & p12 & p13;

endmodule

module X74HC27 (
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

    assign p6  = ~ (p3 | p4  | p5);
    assign p8  = ~ (p9 | p10 | p11);
    assign p12 = ~ (p1 | p2  | p13);

endmodule

module X74LS27 (
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

    assign p6  = ~ (p3 | p4  | p5);
    assign p8  = ~ (p9 | p10 | p11);
    assign p12 = ~ (p1 | p2  | p13);

endmodule

module X74LS30 (
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , input  p6
        , input  p7
        , output p8
        , input  p11
        , input  p12
        , input  p14
);

    assign p8  = ~ (p1 & p2 & p3 & p4 & p5 & p6 & p11 & p12);

endmodule

module X74LS32 (
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

    assign p3  = p1  | p2;
    assign p6  = p4  | p5;
    assign p8  = p9  | p10;
    assign p11 = p12 | p13;

endmodule

module X74LS42 (
          output p1
        , output p2
        , output p3
        , output p4
        , output p5
        , output p6
        , output p7
        , input  p8
        , output p9
        , output p10
        , output p11
        , input  p12
        , input  p13
        , input  p14
        , input  p15
        , input  p16
);

    wire[3:0] n = { p12, p13, p14, p15 };

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

endmodule

module X74HC74 (
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , output reg p5
        , output reg p6
        , input  p7
        , output reg p8
        , output reg p9
        , input  p10
        , input  p11
        , input  p12
        , input  p13
        , input  p14
);

    always @(posedge p3 or negedge p1 or negedge p4) begin
        if (~ p1 | ~ p4) begin
            p5 <= ~ p4;     //  q <= ~ ps
            p6 <= ~ p1;     // _q <= ~ pc
        end else begin
            p5 <=   p2;     //  q <=   d
            p6 <= ~ p2;     // _q <= ~ d
        end
    end

    always @(posedge p11 or negedge p13 or negedge p10) begin
        if (~ p13 | ~ p10) begin
            p9 <= ~ p10;    //  q <= ~ ps
            p8 <= ~ p13;    // _q <= ~ pc
        end else begin
            p9 <=   p12;    //  q <=   d
            p8 <= ~ p12;    // _q <= ~ d
        end
    end

endmodule

module X74HC86 (
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

    assign p3  = p1  ^ p2;
    assign p6  = p4  ^ p5;
    assign p8  = p9  ^ p10;
    assign p11 = p12 ^ p13;

endmodule

module X74LS109 (
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

    always @(posedge p4 or negedge p1 or negedge p5) begin
        if (~ p1 | ~ p5) begin
            p6  <= ~ p5;    //  q <= ~ ps
            p7  <= ~ p1;    // _q <= ~ pc
        end else begin
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
    end

    always @(posedge p12 or negedge p15 or negedge p11) begin
        if (~ p15 | ~ p11) begin
            p10 <= ~ p11;   //  q <= ~ ps
            p9  <= ~ p15;   // _q <= ~ pc
        end else begin
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
    end

endmodule

module Y74LS109 (
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

    always @(posedge p4 or negedge p1 or negedge p5) begin
        $display ("Y74LS109*: p1=%b p2=%b p3=%b p4=%b p5=%b p6=%b p7=%b", p1, p2, p3, p4, p5, p6, p7);
        if (~ p1 | ~ p5) begin
            p6  <= ~ p5;    //  q <= ~ ps
            p7  <= ~ p1;    // _q <= ~ pc
        end else begin
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
    end

    always @(posedge p12 or negedge p15 or negedge p11) begin
        $display ("Y74LS109*: p15=%b p14=%b p13=%b p12=%b p11=%b p10=%b p9=%b", p15, p14, p13, p12, p11, p10, p9);
        if (~ p15 | ~ p11) begin
            p10 <= ~ p11;   //  q <= ~ ps
            p9  <= ~ p15;   // _q <= ~ pc
        end else begin
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
    end

endmodule

module X74HC138 (
          input  p1     // A2
        , input  p2     // A1
        , input  p3     // A0
        , input  p4     // _G0
        , input  p5     // _G1
        , input  p6     // G2
        , output p7     // Y7
        , input  p8     // GND
        , output p9     // Y6
        , output p10    // Y5
        , output p11    // Y4
        , output p12    // Y3
        , output p13    // Y2
        , output p14    // Y1
        , output p15    // Y0
        , input  p16    // VCC
);

    wire g = ~ p4 & ~ p5 & p6;
    wire[2:0] n = { p3, p2, p1 };

    assign p15 = ~ g | (n != 0);
    assign p14 = ~ g | (n != 1);
    assign p13 = ~ g | (n != 2);
    assign p12 = ~ g | (n != 3);
    assign p11 = ~ g | (n != 4);
    assign p10 = ~ g | (n != 5);
    assign p9  = ~ g | (n != 6);
    assign p7  = ~ g | (n != 7);

endmodule

module X74LS139 (
          input  p1     // 1 _E
        , input  p2     // 1 A0
        , input  p3     // 1 A1
        , output p4     // 1 _Y0
        , output p5     // 1 _Y1
        , output p6     // 1 _Y2
        , output p7     // 1 _Y3
        , input  p8     // GND
        , output p9     // 2 _Y3
        , output p10    // 2 _Y2
        , output p11    // 2 _Y1
        , output p12    // 2 _Y0
        , input  p13    // 2 A1
        , input  p14    // 2 A0
        , input  p15    // 2 _E
        , input  p16    // VCC
);

    wire[1:0] n1 = { p3,  p2  };
    wire[1:0] n2 = { p13, p14 };

    assign p4  = p1  | (n1 != 0);
    assign p5  = p1  | (n1 != 1);
    assign p6  = p1  | (n1 != 2);
    assign p7  = p1  | (n1 != 3);

    assign p12 = p15 | (n2 != 0);
    assign p11 = p15 | (n2 != 1);
    assign p10 = p15 | (n2 != 2);
    assign p9  = p15 | (n2 != 3);

endmodule

module X74LS151 (
          input  p1     // d3
        , input  p2     // d2
        , input  p3     // d1
        , input  p4     // d0
        , output p5     //  q
        , output p6     // _q
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

    assign p5 = ~ p7  & ((s == 0) & p4  | (s == 1) & p3  | (s == 2) & p2  | (s == 3) & p1 |
                         (s == 4) & p15 | (s == 5) & p14 | (s == 6) & p13 | (s == 7) & p12);
    assign p6 = ~ p5;

endmodule

module X74LS153 (
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , input  p6
        , output p7
        , input  p8
        , output p9
        , input  p10
        , input  p11
        , input  p12
        , input  p13
        , input  p14
        , input  p15
        , input  p16
);

    wire[1:0] s = { p2, p14 };

    assign p7 = ~ p1  & ((s == 0) & p6  | (s == 1) & p5  | (s == 2) & p4  | (s == 3) & p3);
    assign p9 = ~ p15 & ((s == 0) & p10 | (s == 1) & p11 | (s == 2) & p12 | (s == 3) & p13);

endmodule

module X74LS157 (
          input  p1     // 0=A; 1=B
        , input  p2     // 1A
        , input  p3     // 1B
        , output p4     // 1Y
        , input  p5     // 2A
        , input  p6     // 2B
        , output p7     // 2Y
        , input  p8     // GND
        , output p9     // 3Y
        , input  p10    // 3B
        , input  p11    // 3A
        , output p12    // 4Y
        , input  p13    // 4B
        , input  p14    // 4A
        , input  p15    // _G
        , input  p16    // VCC
);

    assign p4  = ~ p15 & (p1 ? p3  : p2);
    assign p7  = ~ p15 & (p1 ? p6  : p5);
    assign p9  = ~ p15 & (p1 ? p10 : p11);
    assign p12 = ~ p15 & (p1 ? p13 : p14);

endmodule

module X74LS161 (
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

    always @(posedge p2 or negedge p1) begin
        if (~ p1) begin
            { p11, p12, p13, p14 } <= 0;
        end else if (~ p9) begin
            { p11, p12, p13, p14 } <= { p6, p5, p4, p3 };
        end else if (p7 & p10) begin
            { p11, p12, p13, p14 } <= { p11, p12, p13, p14 } + 1;
        end
    end

endmodule

module X74LS174 (
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

    always @(posedge p9 or negedge p1) begin
        if (~ p1) begin
            p2  <= 0;
            p5  <= 0;
            p7  <= 0;
            p10 <= 0;
            p12 <= 0;
            p15 <= 0;
        end else begin
            p2  <= p3;
            p5  <= p4;
            p7  <= p6;
            p10 <= p11;
            p12 <= p13;
            p15 <= p14;
        end
    end

endmodule

module V74LS174 (
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

    always @(posedge p9 or negedge p1) begin
        $display ("V74LS174*: clk=%b _pc=%b d=%02o q=%02o",
                p9, p1, {p3,p4,p6,p11,p13,p14}, {p2,p5,p7,p10,p12,p15});
        if (~ p1) begin
            p2  <= 0;
            p5  <= 0;
            p7  <= 0;
            p10 <= 0;
            p12 <= 0;
            p15 <= 0;
        end else begin
            p2  <= p3;
            p5  <= p4;
            p7  <= p6;
            p10 <= p11;
            p12 <= p13;
            p15 <= p14;
        end
    end

endmodule

module X74LS175 (
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

    always @(posedge p9 or negedge p1) begin
        if (~ p1) begin
            p2  <= 0;
            p7  <= 0;
            p10 <= 0;
            p15 <= 0;
        end else begin
            p2  <= p4;
            p7  <= p5;
            p10 <= p12;
            p15 <= p13;
        end
    end

endmodule

module X74LS283 (
          output p1
        , input  p2
        , input  p3
        , output p4
        , input  p5
        , input  p6
        , input  p7
        , input  p8
        , output p9
        , output p10
        , input  p11
        , input  p12
        , output p13
        , input  p14
        , input  p15
        , input  p16
);

    wire[3:0] a = { p12, p14, p3, p5 };
    wire[3:0] b = { p11, p15, p2, p6 };

    assign { p9, p10, p13, p1, p4 } = { 1'b0, a } + { 1'b0, b } + { 4'b0, p7 };

endmodule

module X74HCT541 (
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
        , output p11
        , output p12
        , output p13
        , output p14
        , output p15
        , output p16
        , output p17
        , output p18
        , input  p19
        , input  p20
);

    wire oe = ~ p1 & ~ p19;
    assign p18 = oe ? p2 : 1'bZ;
    assign p17 = oe ? p3 : 1'bZ;
    assign p16 = oe ? p4 : 1'bZ;
    assign p15 = oe ? p5 : 1'bZ;
    assign p14 = oe ? p6 : 1'bZ;
    assign p13 = oe ? p7 : 1'bZ;
    assign p12 = oe ? p8 : 1'bZ;
    assign p11 = oe ? p9 : 1'bZ;

endmodule

module X74HC4075 (
          input  p1
        , input  p2
        , input  p3
        , input  p4
        , input  p5
        , output p6
        , input  p7
        , input  p8
        , output p9
        , output p10
        , input  p11
        , input  p12
        , input  p13
        , input  p14
);

    assign p6  = p3  | p4  | p5;
    assign p9  = p1  | p2  | p8;
    assign p10 = p13 | p12 | p11;

endmodule

module XCY7C199 (
    input  p1,  // A5
    input  p2,  // A6
    input  p3,  // A7
    input  p4,  // A8
    input  p5,  // A9
    input  p6,  // A10
    input  p7,  // A11
    input  p8,  // A12
    input  p9,  // A13
    input  p10, // A14
    inout  p11, // IO0
    inout  p12, // IO1
    inout  p13, // IO2
    input  p14, // GND
    inout  p15, // IO3
    inout  p16, // IO4
    inout  p17, // IO5
    inout  p18, // IO6
    inout  p19, // IO7
    input  p20, // _CE
    input  p21, // A0
    input  p22, // _OE
    input  p23, // A1
    input  p24, // A2
    input  p25, // A3
    input  p26, // A4
    input  p27, // _WE
    input  p28  // VCC
);

    wire[14:00] a = { p10, p9, p8, p7, p6, p5, p4, p3, p2, p1, p26, p25, p24, p23, p21 };
    reg[7:0] array[32767:0];

    ////always @(*) begin
    ////    $display ("XCY7C199*: %m ce=%b oe=%b we=%b a=%o array[a]=%o", ~p20, ~p22, ~p27, a, array[a]);
    ////end

    assign { p19, p18, p17, p16, p15, p13, p12, p11 } = (~ p20 & ~ p22 & p27) ? array[a] : 8'hZZ;

    always @(negedge p20 or negedge p27) begin
        if (~ p20 & ~ p27) begin
            array[a] = { p19, p18, p17, p16, p15, p13, p12, p11 };
        end
    end

endmodule

module IS61C3216AL (
    input  p1,  // NC
    input  p2,  // A14
    input  p3,  // A13
    input  p4,  // A12
    input  p5,  // A11
    input  p6,  // _CE
    inout  p7,  // IO0
    inout  p8,  // IO1
    inout  p9,  // IO2
    inout  p10, // IO3
    input  p11, // VDD
    input  p12, // GND
    inout  p13, // IO4
    inout  p14, // IO5
    inout  p15, // IO6
    inout  p16, // IO7
    input  p17, // _WE
    input  p18, // A10
    input  p19, // A9
    input  p20, // A8
    input  p21, // A7
    input  p22, // NC
    input  p23, // NC
    input  p24, // A6
    input  p25, // A5
    input  p26, // A4
    input  p27, // A3
    input  p28, // NC
    inout  p29, // IO8
    inout  p30, // IO9
    inout  p31, // IO10
    inout  p32, // IO11
    input  p33, // VDD
    input  p34, // GND
    inout  p35, // IO12
    inout  p36, // IO13
    inout  p37, // IO14
    inout  p38, // IO15
    input  p39, // _LB
    input  p40, // _UB
    input  p41, // _OE
    input  p42, // A2
    input  p43, // A1
    input  p44  // A0
);

    wire[14:00] a = { p2, p3, p4, p5, p18, p19, p20, p21, p24, p25, p26, p27, p42, p43, p44 };
    reg[7:0] loarray[32767:0];
    reg[7:0] uparray[32767:0];

    assign { p16, p15, p14, p13, p10, p9,  p8,  p7  } = (~ p6 & p17 & ~ p41 & ~ _p39) ? loarray[a] : 8'hZZ;
    assign { p38, p37, p36, p35, p32, p31, p30, p29 } = (~ p6 & p17 & ~ p41 & ~ _p40) ? hiarray[a] : 8'hZZ;

    always @(*) begin
        if (~ p6 & ~ p17) begin
            if (~ p39) loarray[a] = { p16, p15, p14, p13, p10, p9,  p8,  p7  };
            if (~ p40) hiarray[a] = { p38, p37, p36, p35, p32, p31, p30, p29 };
        end
    end

endmodule
