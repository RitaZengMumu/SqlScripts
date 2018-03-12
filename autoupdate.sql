-----------���ݿ�ÿ���Զ����½ű���������ְ����ְ��Ȩ�޵������Ϣ
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

          
CREATE PROCEDURE [dbo].[USP_ATS_AutoUpdateUserData]                      
AS                      
BEGIN                      
                       
 INSERT INTO users                      
(companycode,usercode,english,chinese,usergroupcode,userpassword,empid,datemask,                      
timemask,employeefilter,theme,language,empnamemode,recordperpage,locked,email,                      
createuser,createusergroup,createtime,mod_user,mod_time,validationtype,adname,                      
needmodifypwd,japanese,big5,SecPWD,encrypttype,needmodifysecpwd)                      
SELECT 'StrategyDBCompany',b.empcode,b.english,b.chinese,'',                    
--''                      
(SUBSTRING(sys.fn_VarBinToHexStr(hashbytes('MD5',cast(right(pid,6) as varchar(50))) ),3,32))                      
,b.empid,'yyyy-MM-dd',                      
'','',0,0,0,20,0,b.cemail,                      
'admin','admins',GETDATE(),'admin',GETDATE(),0,'',                      
1,'','',                    
--''                      
(SUBSTRING(sys.fn_VarBinToHexStr(hashbytes('MD5',cast(right(pid,6) as varchar(50))) ),3,32))                     
--(select substring(sys.fn_VarBinToHexStr(hashbytes('MD5',SUBSTRING(cast(NEWID() as varchar(50)),1,6)) ),3,8)),                      
,1,1                      
FROM emphr b                       
WHERE b.empid not in (select empid from users)                      
and b.servicestatus = 0                      
and b.employeeflag = 1                      
                      
 update users                      
 set email = a.cemail                      
 from emphr a                      
 where a.empid = users.empid                      
           
 ----����Ĭ��Ȩ��          
update users set usergroupcode = 'Leader' where usergroupcode = '' and empid in (          
Select supervisorempid from empposition where empposition.currentposition=1 and empposition.defaultposition=1)          
update users set usergroupcode = 'Manager' where usergroupcode = '' and empid in (          
Select deptmgrempid from empposition where empposition.currentposition=1 and empposition.defaultposition=1)          
update users set usergroupcode = 'Nomal' where usergroupcode = ''           
                     
-- --�����Ű�                    
insert ats_emproster (empid,effectivedate,rosterid,mod_user,mod_time,flag)                    
select empid,                    
case when hiredate IS null then '2015-01-01' else hiredate end,                    
'001','admin',GETDATE(),'1' from emphr where empid not in (                    
select empid from ats_emproster)                    
--and LEN(empcode)=8                    
--���ÿ��ڿ���                    
insert ats_empattcode (empid,effectivedate,attcode,mod_user,mod_time,flag)                    
select empid,                    
case when hiredate IS null then '2015-01-01' else hiredate end,                    
empcode,'admin',GETDATE(),'1' from emphr where empid not in (                    
select empid from ats_empattcode)                      
--����Ա���������                    
insert ats_empbasicpolicy (empid,effectivedate,basicid,mod_user,mod_time,flag)                    
select empid,                    
case when hiredate IS null then '2015-01-01' else hiredate end,                    
'Basic','admin',GETDATE(),'1' from emphr where empid not in (                    
select empid from ats_empbasicpolicy)                    
and LEN(empcode)=8                    
--����Ա������                    
update emppayroll set holidayclass='DefaultClass' where holidayclass=''                    
                   
                  
                  
--��ְԱ��-������ְ�����Զ������ʻ�                  
UPDATE users                   
  SET locked = 1                   
WHERE empid NOT IN (select empid from [StrategyDBCompany_All_Active_Employees]) and                   
      empid in (select empid                   
                  from emphr                  
                 where quitdate <= getdate() and                   
                       quitdate is not null)                  
                  
----��ְԱ���������                  
--update emphr set cemail='' where quitdate < GETDATE() and cemail<>''                  
             
--exec [USP_ATS_AutoUpdateUserData]                  
                
                
--ÿ��16�ո��¿����ڶ�                
DECLARE @Number int                
 set @Number = day (GETDATE())                
if @Number= 16                
 begin                
 insert payperiod (companycode,yearcode,paybegindate,payenddate,attbegindate,attenddate)               
 select 'StrategyDBCompany',YEAR (getdate()),null,null,convert(varchar(10),getdate(),120),convert(varchar(10),dateadd(mm,1,getdate())-1,120)  
 where   convert(varchar(10),getdate(),120) not in (Select attbegindate from payperiod)
 update control set attbegindate=convert(varchar(10),getdate(),120),attenddate=convert(varchar(10),dateadd(mm,1,getdate())-1,120)                
 end                
else                 
 PRINT 'date day is not 16.'                
                 
                
--����н���ڶ�                
update payperiod set paybegindate=attbegindate,payenddate=attenddate                
                  
--����Ա��������ϵ              
update ehr set timekeepadmin=epos.supervisorempid,timekeeper2=deptmgrempid from empposition as epos              
inner join emphr as ehr on epos.empid=ehr.empid              
where epos.currentposition=1 and defaultposition=1                 
----�����Զ����ֶ���ʹ�ÿ��ڵĹ�          
update empself set EmpUseAttFlag = 1 where EmpUseAttFlag = 0              
          
          
----����ÿ�±�׼����ʱ��          
update payperiod set stanhours=dbo.[f_workday](attbegindate,attenddate)*8             
          
-----�Զ���������ϵ          
insert S_WF_Delegate_emp (processid,empid,authempid,auth_out,startdt,enddt,companycode,mod_user,mod_time)          
select '28',empid,supervisorempid,'0','2016-01-01 00:00:00.000','2099-01-01 00:00:00.000',          
'StrategyDBCompany','admin',GETDATE()          
 from empposition          
 where  supervisorempid<>0 and empposition.currentposition=1 and empposition.defaultposition=1 and empid not in (          
 select empid from S_WF_Delegate_emp where processid=28)          
           
 insert S_WF_Delegate_emp (processid,empid,authempid,auth_out,startdt,enddt,companycode,mod_user,mod_time)          
select '29',empid,supervisorempid,'0','2016-01-01 00:00:00.000','2099-01-01 00:00:00.000',          
'StrategyDBCompany','admin',GETDATE()          
 from empposition          
 where  supervisorempid<>0 and empposition.currentposition=1 and empposition.defaultposition=1 and empid not in (          
 select empid from S_WF_Delegate_emp where processid=29)          
           
update S_WF_Delegate_emp set authempid=supervisorempid from S_WF_Delegate_emp          
 inner join empposition on S_WF_Delegate_emp.empid=empposition.empid          
 where empposition.currentposition=1 and empposition.defaultposition=1          
           
           
----�޸Ľ����Ű�          
insert empfront          
select 'StrategyDBCompany',usercode,'c_1:divEmpBase,divCheckIn,divShareFile,divNewEmp,divTodo;c_2:divAttMars,divAtt,divHRReprt,divMytraning,divVacantJob;c_3:divAddressList,divVote,divEmpty1;'          
from users where usercode not in ( select usercode from empfront)          
          
  --��ӹ���        
  insert ats_roster_h(companycode,rosterid,english,chinese)        
select 'StrategyDBCompany',orgcode,english,chinese from organization where orglevel=3 and orgcode not in (        
select rosterid from ats_roster_h)        
        
--���ù���Ȩ��        
insert ats_rostersecurity (companycode,usergroupcode,rosterid,accessright)        
select * from (        
select 'StrategyDBCompany' companycode,'HROther' usergroupcode,orgcode,1 as '1' from organization where orglevel=3        
union all         
select 'StrategyDBCompany','HRAttendance',orgcode,1 from organization where orglevel=3        
union all         
select 'StrategyDBCompany','admins',orgcode,1 from organization where orglevel=3        
union all         
select 'StrategyDBCompany','Manager',orgcode,1 from organization where orglevel=3        
union all         
select 'StrategyDBCompany','Leader',orgcode,1 from organization where orglevel=3        
union all         
select 'StrategyDBCompany','HRadmins',orgcode,1 from organization where orglevel=3        
union all         
select 'StrategyDBCompany','Nomal',orgcode,1 from organization where orglevel=3) a where a.orgcode not in (        
select rosterid from ats_rostersecurity )        
      
---�Զ�����������      
UPDATE empself set anlvclass='TFAPM' where empid in (      
select empid from emphr where emptype in ('TFA','PM')) and anlvclass=''      
UPDATE empself set anlvclass='OW' where empid in (      
select empid from emphr where emptype in ('OW')) and anlvclass=''      
      
      
---�Զ�����GAP�еĲ��ų�����Ա�����ϼ�����      
update empposition set  empposition.supervisorempid=organization.headempid from emphr       
inner join empposition on emphr.empid=empposition.empid      
inner join organization on emphr.orgcode3=organization.orgcode      
where orglevel=3 and empposition.currentposition=1 and empposition.defaultposition=1      
and emphr.orgcode3<>'' and headempid<>0 and servicestatus=0      
    
    
---�޸����ܲ鿴Ա����Ȩ��    
update emphr set timekeepadmin=empposition.supervisorempid from emphr     
inner join empposition on emphr.empid =  empposition.empid    
where empposition.defaultposition=1 and empposition.currentposition=1    
----�����ܶ��Լ������Ű�    
update emphr set timekeeper2=emphr.empid from emphr     
inner join empposition on emphr.empid =  empposition.empid    
where empposition.defaultposition=1 and empposition.currentposition=1    
and  empposition.empid in (Select supervisorempid from empposition     
where empposition.defaultposition=1 and empposition.currentposition=1)    
----��ְԱ������ʾ������Ա����    
update emphr set timekeepadmin=999999 where quitdate<(Select attbegindate from control)    
  
  
------�쳣��������ɹ����Զ�����ԭʼ�򿨼�¼��  
insert ats_originaldata (originaldata,cardid,empid,att_datetime,machineid,inorout,companycode)  
select '�쳣��������ͬ��',empcode,ESS_AtsException.empid,new_in1,1,1,(select chinese from companies) from ESS_AtsException   
left join emphr on ESS_AtsException.empid=emphr.empid where ESS_AtsException.isupdate=0   
and status='node_2'  
insert ats_originaldata (originaldata,cardid,empid,att_datetime,machineid,inorout,companycode)  
select '�쳣��������ͬ��',empcode,ESS_AtsException.empid,new_out1,1,1,(select chinese from companies) from ESS_AtsException   
left join emphr on ESS_AtsException.empid=emphr.empid where ESS_AtsException.isupdate=0  
and status='node_2'  
update ESS_AtsException set isupdate=1 where ESS_AtsException.isupdate=0 and status='node_2'  
    


------�����û�����web���ʺ�
--update users set locked=1 where empid in(Select empid from emphr where party in ('AP','Hourly','TP','ULTD02'))
 
 --�Զ�����8��ǰ�Ŀ���
 update ats_ioimport set postflag=1
where year(att_date)=year(GETDATE()-8)
and month(att_date)=month(GETDATE()-8)
and day(att_date)=day(GETDATE()-8)

-----�����ƶ�ǩ���Ŀ�������
insert ats_originaldata
select '','',emphr.empcode,UsersSignIn.empid,
UsersSignIn.signintime,'99','1',
UsersSignIn.companycode,0,'',null,0,position from dbo.UsersSignIn 
left join emphr on UsersSignIn.empid=emphr.empid
where UsersSignIn.empid in (
select empid from StrategyDBCompany_MobileCheckinemp 
--where empid=116473 and signintime='2016-03-29 07:26:54.570'
) and UsersSignIn.empid+UsersSignIn.signintime not in (select empid+att_datetime from  ats_originaldata)
          
    --exec [USP_ATS_AutoUpdateUserData]              
                  
END 


GO


