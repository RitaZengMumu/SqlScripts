
/*
邮件模板存储过程，本存储过程为 查询每个考勤期段实际工作小时数小于法定工作小时数的员工汇总，在系统中配置邮件的每月发送日期，系统会自动执行该存储过程
*/


CREATE procedure [dbo].[usp_LessWorktime]
	 
AS
	/*
	考勤期段：每个月的16号到下月15号，获取每个考勤期段应工作小时数和实际工作小时数，实际工作小时数小于应工作小时数的，发邮件给直属主管
	*/
BEGIN

	DECLARE @result		nvarchar(max)
	DECLARE @rowstr		nvarchar(max)		--每行的描述
	DECLARE @iLoop		int
	DECLARE @lst_SuperEmpid		int	
	DECLARE @this_SuperEmpid	int
	DECLARE @SHead		nvarchar(max)
	
	DECLARE @PeroidBegin datetime
	DECLARE @PeriodEnd datetime

	set @PeriodEnd=CONVERT(nchar(10),dateadd(day,-DATEPART(day,getdate())+15,getdate()),120)
	select @PeroidBegin = dateadd(day, 1,dateadd(month,-1,@PeriodEnd)) 
	select @PeriodEnd = @PeriodEnd + ' 23:59:59'
  
   
	set @lst_SuperEmpid = 0
	---表格的Title
	set @SHead = N'<table border="1"><tr><td>工号</td><td>姓名</td><td>部门</td><td>标准工作小时数</td><td>实际工作小时数</td></tr>'

	CREATE TABLE #tblR (empid int, cont nvarchar(max))

	BEGIN
		
		DECLARE cur CURSOR FOR
			select tar.supervisorempid, 
			'<tr><td>' + tar.empcode + 
			'</td><td>' + tar.empcname + 
			 '</td><td>' + CAST(CAST(tar.Regtime AS DECIMAL(18,1)) AS VARCHAR)+  
			 '</td><td>' + CAST(CAST(tar.Realtime AS DECIMAL(18,1)) AS VARCHAR) + 
            '</td></tr>'
			  from (
select hr.empid,hr.empcode,hr.chinese as empcname,pos.supervisorempid,io.Regtime ,io.Realtime 
from 
( select a.empid,sum(a.regwktime) as Regtime ,sum(a.worktime)as Realtime from ats_ioimport a,emphr b 
where a.empid=b.empid and a.att_date between @PeroidBegin and @PeriodEnd 
and b.hiredate<=@PeroidBegin and b.adminemp=1  group by a.empid
 union all
 select a.empid,sum(a.regwktime)as Regtime,sum(a.worktime)as Realtime from ats_ioimport a,emphr b 
where a.empid=b.empid and a.att_date between b.hiredate and @PeriodEnd and b.hiredate>@PeroidBegin and b.adminemp=1
 group by a.empid) io 
 left join emphr hr on hr.empid=io.empid
left join(select * from  empposition where currentposition = 1 and defaultposition = 1) pos ON hr.empid = pos.empid

) tar 
order by tar.supervisorempid, tar.empid
		OPEN cur
		FETCH NEXT FROM cur INTO @this_SuperEmpid , @rowstr
			WHILE @@FETCH_STATUS = 0
			BEGIN	
				IF (@this_SuperEmpid <> @lst_SuperEmpid)
				BEGIN
					INSERT INTO #tblR (empid, cont) VALUES(@this_SuperEmpid, @rowstr)
					SET @lst_SuperEmpid = @this_SuperEmpid
				END
				ELSE
					UPDATE #tblR SET cont = cont + @rowstr WHERE empid = @this_SuperEmpid
				
				FETCH NEXT FROM cur INTO  @this_SuperEmpid , @rowstr
			END
		CLOSE cur
		DEALLOCATE cur
	END
		SELECT a.empid, b.chinese as supername,  @SHead + a.cont + '</table>' as [desc] 
	FROM #tblR a INNER JOIN emphr b ON a.empid = b.empid
	

END


GO


