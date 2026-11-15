# shellcheck shell=bash
# run-08 (A). Lean: verification/QuoteRoundTrip.lean has no executable link -> 検知不能.
# Executable check: the random test run with node -e in the session (05:36:58), copied verbatim.
# VIOLATION_RE: failures [1-9]|Error
node -e '
const {parse,publish}=require("./index.js");
const A=["\\\\","\x27","\"","a","b"," ","\n"];let n=0,fail=[];
for(let i=0;i<200000;i++){let s="";const L=Math.random()*8|0;for(let j=0;j<L;j++)s+=A[Math.random()*A.length|0];
 for(const qs of ["single","double"]){
  const nodes=[{type:"STRING_VALUE",string:s,quoteStyle:qs},
   {type:"MEMBER",owner:{type:"NAME",name:"A"},name:s,quoteStyle:qs,hasEventPrefix:false},
   {type:"RECORD",entries:[{type:"RECORD_ENTRY",key:s,quoteStyle:qs,value:{type:"NAME",name:"T"},readonly:false}]}];
  for(const nd of nodes){n++;let out=publish(nd),back;try{back=parse(out)}catch(e){fail.push([nd.type,qs,JSON.stringify(s),out,"PARSE ERROR"]);continue}
   const got=nd.type==="STRING_VALUE"?back.string:nd.type==="MEMBER"?back.name:back.entries[0].key;
   if(got!==s)fail.push([nd.type,qs,JSON.stringify(s),out,JSON.stringify(got)]);}}}
console.log("cases",n,"failures",fail.length);console.log(fail.slice(0,5));'
