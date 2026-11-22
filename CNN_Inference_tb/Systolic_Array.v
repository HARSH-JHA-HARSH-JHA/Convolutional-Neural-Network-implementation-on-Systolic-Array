module Systolic_Array #(parameter bit = 3,m = 2,n = 4,width = 5) (clk,rst,row,column,out);
input clk,rst;
input [m*bit-1:0] row;
input [n*bit-1:0] column;
output [m*n*width-1:0] out;

wire [bit-1:0] a[1:m][1:n+1];
wire [bit-1:0] b[1:m+1][1:n];
wire [width-1:0] c[1:m][1:n];

genvar i,j;
generate for(i=1;i<=m;i=i+1) begin:gen1
assign a[i][1] = row[bit*i-1 -: bit];
for(j=1;j<=n;j=j+1) begin:gen2
assign out[i*n*width+j*width-width*n-1 -: width] = c[i][j];
PE #(bit,width) p1(.rst(rst),.clk(clk),.ain(a[i][j]),.bin(b[i][j]),.aout(a[i][j+1]),.bout(b[i+1][j]),.cout(c[i][j]));
end
end
for(j=1;j<=n;j=j+1) begin:gen3
assign b[1][j] = column[bit*j-1 -: bit];
end
endgenerate

endmodule 