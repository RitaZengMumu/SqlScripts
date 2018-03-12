
-----员工年假报表，员工可以查看自己和下属的信息

CREATE PROCEDURE [dbo].[USP_ATS_LVRpt]
	
	--@Filter nvarchar(200),       -- 当前操作用户过滤
	@PeriodEnd datetime,         -- 考勤期段结束日期
	--@deptcode	nvarchar(50),     -- 查询的部门
	--@SuperEmpid	int,				-- 主管empid
	--@companycode	nvarchar(50)  -- 公司代码
	@empcode NVARCHAR(20)
	
AS
BEGIN
	DECLARE @SQL nvarchar(2000)
	DECLARE @PeroidBegin datetime
	Declare @PreView nvarchar(50)
	
	DECLARE @Filter nvarchar(200)       -- 当前操作用户过滤(要去掉前后的[])
	DECLARE @deptcode	nvarchar(50)     -- 查询的部门
	DECLARE @companycode	nvarchar(50)  -- 公司代码
	DECLARE @SuperEmpid	int		
	         	             		 
	SET @Filter = ''
	SET @deptcode =''
	SET @companycode = 'StrategyDBCompany'
	SET @SuperEmpid = ''
	
	select @SQL = ''
	select @PeroidBegin = dateadd(day, 1,dateadd(month,-1,@PeriodEnd)) 
	select @PeriodEnd = @PeriodEnd + ' 23:59:59'
	
	if @companycode = 'MRMT'
	   begin
	     select @PreView = 'MRMT_'
	   end 
	else
	   begin
	    select @PreView = 'StrategyDBCompany_'
	   end 
	
	/**********************************************************************/   
	-- 如果临时表存在，则删除 
	if object_id('tempdb.dbo.#AnLvTmp') is not null 
	begin
		drop table dbo.#AnLvTmp
	end
	
	-- 创建临时表
	create table #AnLvTmp  --创建临时表#Tmp
            (empid int not null default(0), 
             empcode nvarchar(50) not null default(''),
             english nvarchar(50) not null default(''),
             chinese nvarchar(50) not null default(''),
             dept nvarchar(200) not null default(''),
             M1 float not null default(0),
             M2 float not null default(0),
             M3 float not null default(0),
             M4 float not null default(0),
             M5 float not null default(0),
             M6 float not null default(0),
             M7 float not null default(0),
             M8 float not null default(0),
             M9 float not null default(0),
             M10 float not null default(0),
             M11 float not null default(0),
             M12 float not null default(0),
			Total float not null default(0),
             Used float not null default(0),
             Balance float not null default(0)
            )
            
   -- 按员工过滤，将本考勤期段内的"现职员工"的，过滤范围内的， 所选部门的，插入临时表
	if @SuperEmpid > 0 
	   begin
			select @SQL = 'select empid,empcode, chinese, english from emphr where empid in (select empid from empposition where currentposition=1 and supervisorempid=''' + 	cast( @SuperEmpid as nvarchar) + ''')'
	   end
	else if @Filter <> ''  and  @Filter is not null
	   begin 
	        select @Filter = @PreView + @Filter     	
	        select @SQL = 'select empid,empcode, chinese, english from emphr where empid in (select empid from [' + @Filter + '])'        
	   end 
	 else
	   begin
	        select @SQL = 'select empid,empcode, chinese, english from emphr where  companycode = ''' + @companycode + ''' '
	   end 
	
	 if @deptcode <> ''  and  @deptcode is not null
	    begin 
	       select @SQL = @SQL + ' and orgcode2 = ''' + @deptcode + ''''
	    end
	
		select  @SQL ='insert into #AnLvTmp (empid,empcode,chinese,english) ( ' + @SQL + ')'
		exec sp_executesql  @sql
	
	update #AnLvTmp
	set dept  = a.english
	from organization a, emphr e
	where #AnLvTmp.empid = e.empid and a.orgcode = e.orgcode2
	
	
	/**********************************************/	
    -- 根据考勤期段循更新每人各月的年假使用情况及天数
	declare @monthbegin datetime
	declare @monthend datetime
	declare @iStep int 
	
	select @iStep = 1
	
	while @iStep < 12
		begin
		    select @monthbegin = convert(datetime,convert(char(4),year(@PeriodEnd)) + '-' + CONVERT(nvarchar(2),@iStep) + '-01')
		    select @monthend = dateadd(day,-1,DATEADD(month,1,@monthbegin))
		    
		    select @SQL = ''
			select @SQL = ' update #AnLvTmp set M' + CONVERT(nvarchar(2),@iStep) + 
			              ' = round(T1.tt ,2) from ( ' +
			              'select a.empid, round(count(leavetime1) / 8.0,1) as tt from ats_ioimport a, #AnLvTmp b ' +
			              ' where a.empid = b.empid and att_date >= ''' + convert(nvarchar(50),@monthbegin) + ''' and att_date <= ''' + convert(nvarchar(50),@monthend)  + ''' and ' +
			              ' leaveid1 = 0 and leavetime1 > 0 group by a.empid) T1  where #AnLvTmp.empid  = T1.empid '
			              
			exec sp_executesql  @sql		    
			select @iStep = @iStep  + 1
			
		end
	
	
	
	/**********************************************/
	--返回结果
	--
	IF @empcode<>'' AND @empcode IS NOT NULL 
		select * from #AnLvTmp WHERE empcode = @empcode
	ELSE
		select * from #AnLvTmp
	
	-- exec dbo.USP_ATS_LVRpt '','2015-07-31','',729,'StrategyDBCompany'
	
END

GO


