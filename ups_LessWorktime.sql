
/*
�ʼ�ģ��洢���̣����洢����Ϊ ��ѯÿ�������ڶ�ʵ�ʹ���Сʱ��С�ڷ�������Сʱ����Ա�����ܣ���ϵͳ�������ʼ���ÿ�·������ڣ�ϵͳ���Զ�ִ�иô洢����
*/


CREATE procedure [dbo].[usp_LessWorktime]
	 
AS
	/*
	�����ڶΣ�ÿ���µ�16�ŵ�����15�ţ���ȡÿ�������ڶ�Ӧ����Сʱ����ʵ�ʹ���Сʱ����ʵ�ʹ���Сʱ��С��Ӧ����Сʱ���ģ����ʼ���ֱ������
	*/
BEGIN

	DECLARE @result		nvarchar(max)
	DECLARE @rowstr		nvarchar(max)		--ÿ�е�����
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
	---����Title
	set @SHead = N'<table border="1"><tr><td>����</td><td>����</td><td>����</td><td>��׼����Сʱ��</td><td>ʵ�ʹ���Сʱ��</td></tr>'

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


