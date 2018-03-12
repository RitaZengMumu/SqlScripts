/*
 考勤员查询自己名下的员工的某期段内的考勤汇总，涉及考勤系统和人事薪资系统两个数据库
*/


CREATE  PROCEDURE [dbo].[usp_ats_ReviewSum_Rpt] 
	 @empcode		  nvarchar(50),  --查某个考勤员编码
	 @currentusercode nvarchar(200), --当前员工(系统内置）
	 @begindate       datetime,  --期段开始日期
	 @enddate		  datetime   --期段结束日期
AS
begin
	DECLARE @SQL nvarchar(500)
	
	 /**********************************************************************/   
	-- 如果临时表存在，则删除 
	if object_id('tempdb.dbo.#Tmp') is not null 
	begin
		drop table dbo.#Tmp
	end
	

	/************************************************************************/
	-- 处理uvw_ats_ioimport, 将白班，夜班，OT3先拆分好
	-- 1. 先处理开始或结束日期是法定日的
	-- 2. 再处理开始与结束均不是法定日的
	if object_id('tempdb.dbo.#ats_ioimport') is not null 
	begin
		drop table dbo.#ats_ioimport
	end

	select *,
		         -- 第二天是法定，取第二天0点开始的进段 - 休假 - 中间休息
	       case when isnull((select daytype from holiday_d where convert(nvarchar(10),in_time, 120) = holidaydate),'') <> 'H'  and 
	                 isnull((select daytype from holiday_d where convert(nvarchar(10),out_time, 120) = holidaydate),'') = 'H'  and
	                 (out_time > dayend and io2 > dayend)
							then round(datediff(minute, 
                                                case when (case when io1 > in_time then io1 else in_time end ) < dayend then dayend 
                                                     else (case when io1 > in_time then io1 else in_time end ) end,  -- 来的时间比排班晚，则取来的时间；在跨天后，取24：00
                                               (case when io2 < out_time then io2 else out_time end ) 
                                                ) / 60.0 , 2)  - leavetime1 
                                                               - leavetime2 
                                                               - (case	when (breakbegin < dayend and breakend > dayend) 
																		then round(datediff(minute,  
																					  (case when io1 <= dayend then dayend 
																					        when io1 >= dayend and io1 <= breakend then io1 
																					        else breakend end),
																					  (case when io2 >= dayend and io2 < = breakend then io2 
																					        when io2 >= breakend then breakend
																					        else breakend end) ) / 60.0,2) 
																		when (breakbegin >= dayend )
																		then round(datediff(minute,  
																					  (case when io1 < breakbegin  then breakbegin 
																					        when io1 >= breakbegin and io1 <= breakend then io1 
																					        else breakend end),
																					  (case when io2 >= breakend then breakend
																					        when io2 >= breakbegin and io2 <= breakend then io2
																					        else breakbegin end) ) / 60.0,2) 
																		else 0 end )                                                                            
	            when isnull((select daytype from holiday_d where convert(nvarchar(10),in_time, 120) = holidaydate),'') = 'H'  and 
	                 isnull((select daytype from holiday_d where convert(nvarchar(10),out_time, 120) = holidaydate),'') = 'H' 
							then worktime - leavetime1 - leavetime2
							--round(datediff(minute, 
       --                                         (case when io1 > in_time then io1 else in_time end ),
       --                                         (case when io2 < out_time then io2 else out_time end )
       --                                         ) / 60.0 , 2) 
				when isnull((select daytype from holiday_d where convert(nvarchar(10),in_time, 120) = holidaydate),'') = 'H'  and 
	                 isnull((select daytype from holiday_d where convert(nvarchar(10),out_time, 120) = holidaydate),'') <> 'H'  and 
	                 (in_time < dayend and io1 < dayend) 
							then round(datediff(minute, 
                                               (case when io1 > in_time then io1 else in_time end ),  -- 来的时间比排班晚，则取来的时间；在跨天后，取24：00
                                               case when (case when io2 > out_time then out_time else io2 end ) > dayend then dayend 
                                                     else (case when io2 > out_time then out_time else io2 end ) end  -- 来的时间比排班晚，则取来的时间；在跨天后，取24：00
                                                ) / 60.0 , 2)  - leavetime1 
                                                               - leavetime2
                                                               - (case	when (breakbegin < dayend and breakend > dayend) 
																		then round(datediff(minute,  
																					  (case when io1 <= breakbegin then breakbegin
																					        when io1 >= breakbegin and io1 <= dayend then io1 
																					        else dayend end),
																					  (case when io2 >= dayend then dayend 
																					        when io2 >= breakbegin and io2 <= dayend then io2
																					        else dayend end) ) / 60.0,2) 
																		when (breakend <= dayend )
																		then round(datediff(minute,  
																					  (case when io1 <= breakbegin then breakbegin
																					        when io1 >= breakbegin and io1 <= breakend  then io1   
																					        else breakend end),
																					  (case when io2 >= breakend then breakend
																					        when io2 >= breakbegin and io2 <= breakend  then io2   
																					        else breakend end) ) / 60.0,2) 
																		else 0 end)
				else 0 end  as OT3
	into #ats_ioimport
	from uvw_ats_ioimport
	where att_date > = @begindate and att_date <= @enddate and empid not in (select empid from emphr where orgcode5 = '07')
	
	update #ats_ioimport set OT3 = 0 where OT3 < 0
	

	-- 创建临时表
	create table #Tmp  --创建临时表#Tmp
		(empid int not null default(0), 
		empcode nvarchar(50) not null default(''),
		english nvarchar(200) not null default(''),
		chinese nvarchar(200) not null default(''),
		regwktime float not null default(0),	--排班小时数 
		stdwktime float not null default(0),	--标准小时时
		wkgap     float not null default(0),	--差异		
		Dayreal   float not null default(0),	--实际白班
		paidleave	float not null default(0),	--带薪休假小时数
		nightreal float not null default(0),	--实际夜班--------（实际上班小时数， 不包括加班）
		nightnum float not null default(0),	--夜班次数
		OT1		float not null default(0),  --OT1
		OT2       float not null default(0)   ,--OT2
		OT3       float not null default(0)   ,--OT3
		OTCom     float not null default(0)   ,--OT Com
		OTComPay  float not null default(0)  ,--OT Com Pay
		OnCallIn  float not null default(0)   ,--On Call (In house)   
		OnCallHome	float not null default(0)   ,--On Call（Home）
		nopaylv	float not null default(0)    ,--事假小时
		sicklv	float not null default(0),     --病假小时
		worktime float not null default(0), ---实际工作小时
		totalhour float not null default(0), -- 总计薪小时数 （实际白班+带薪休假+实际夜班）
		status nvarchar(50) not null default(''), ---考勤员提交状态
		tkempid int not null default(0),
		tkempcode nvarchar(50) not null default(''),
		tkname nvarchar(50) not null default(''),
		OT3H	float not null default(0)			--排班在法定的OT3
       )
    
     /**********************************************************************/ 
     -- 确定展示的员工范围
 --   if @empcode <> 0
	--	begin
	--		-- 查询单个员工
	--		insert into #Tmp(empid,empcode,english,chinese)
	--			(select empid,empcode,english,chinese
	--			   from emphr 
	--			  where empcode like @empcode or chinese like @empcode or english like @empcode )
	--	end
	--else
	--	begin
					
			-- 查询考勤员下所有员工或非考勤员按查询过滤
			declare @timekeeper int
			declare @UserID int
			declare @Filter nvarchar(50)
			--declare @count int
			
			-- 取考勤员的empid
			select @timekeeper = empid 
			  from emphr 
			 where empcode = @empcode or chinese = @empcode or english = @empcode
			 
			-- 取当前用户的员工过滤
			select @userid = empid, @filter = employeefilter from users where usercode = @currentusercode
			if (@Filter <> '') 
				begin
					set @Filter = left(@Filter,len(@Filter) - 1)
					set @Filter = right(@Filter,len(@Filter) - 1)
				end
			
			--select @count = count(*) from emphr 
			-- where (timekeeper=@userid or timekeeperid2 = @userid or timekeepadmin = @userid) and 
			--        empid in (select empid from [StrategyDBCompany_All_Active_Employees])
			
			if (@empcode = '')
				begin
					-- 非考勤员，（如HR, 但必须设员工过滤）
					set @SQL = ' insert into #Tmp(empid,empcode,english,chinese) ' + 
						       ' (select empid,empcode,english,chinese ' +
						       ' from emphr ' +
						       ' where empid in (select empid from [StrategyDBCompany_' + @Filter + ']))'
				     exec sp_executesql @SQL 
				     --print @sql
				end
			else
				-- 考勤员
				begin
					insert into #Tmp(empid,empcode,english,chinese)
						(select empid,empcode,english,chinese
						   from emphr 
						  where (timekeeper=@userid or timekeeperid2 = @userid or timekeepadmin = @userid) and 
						        empid in (select empid from [StrategyDBCompany_All_Active_Employees]))
				end
			
		--end
 
    /******************************************************************
     统计相关指标
    ***************/  
    

	-- 标准小时数
	update #Tmp
	   set stdwktime = a.stanhours
	  from payperiod a
	 where a.attbegindate = @begindate

	--update #Tmp
	--   set stdwktime = stdwktime * emphr.fte
	--  from emphr 
	-- where #Tmp.empid = emphr.empid
	
	--2015/11/27查看FTE的变动时间
     update #Tmp
	    set stdwktime = stdwktime * (CASE WHEN emphr.fte_date<@enddate or emphr.fte_date is null THEN  emphr.fte ELSE ess_anlvyear.FTEhis end)
	  from emphr,ess_anlvyear
	 where #Tmp.empid = emphr.empid AND #Tmp.empid=ess_anlvyear.empid AND ess_anlvyear.curflag=1
	
	---- 排班小时数/排班时差
	update #Tmp
	   set regwktime = a.regwktime      
	  from (select empid, sum(regwktime) regwktime	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
	
	---- 实际上班小时
	update #Tmp
	   set worktime = a.worktime	       
	  from (select empid, sum(worktime) worktime	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
	
	/**********************************************
	实际上班的白班时数[Day Shift]，夜班时数[Night Shift],按8点拆分[UFH Shift]
	shiftclassid,workhourid, worktime
	***********************************************/
	-- 白班
	update #Tmp
	   set Dayreal = a.worktime       
	  from (select empid, sum(worktime) worktime	               
	          from uvw_ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               (workhourid in (select workhourid from ats_workhourcls where  shiftclassid = 'Day Shift') or 
	                (workhourid in (select workhourid from ats_workhourcls where  shiftclassid = 'UFH Shift') and io2 <= stdhour )
	                ) and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 

	-- 夜班
	update #Tmp
	   set nightreal = a.worktime,
	       nightnum = a.nightnum      
	  from (select empid, sum(worktime) worktime,count(*) nightnum	               
	          from uvw_ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               (workhourid in (select workhourid from ats_workhourcls where  shiftclassid = 'Night Shift') or 
	                (workhourid in (select workhourid from ats_workhourcls where  shiftclassid = 'UFH Shift') and io1 >= stdhour )
	                ) and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 


	-- 按8点拆分的白夜班(进入与排班开始时间以晚的为准，离开与排班结束时间以早的为准）
	-- 添加了“晚8点后上班4小时记1次夜班”
	update #Tmp
	   set Dayreal = #Tmp.Dayreal + a.Dayreal ,
	       nightreal = #Tmp.nightreal + a.nightreal,
	       nightnum = #Tmp.nightnum + a.nightnum      
	  from (select empid, 
		           sum(datediff(minute, 
		                       (case when io1 <= in_time then in_time else io1 end),
		                       (case when io2 >= stdhour then stdhour else io2 end )) / 60.0 - 
		                       case when ( breakend <= stdhour) then datediff(minute, breakbegin,breakend) / 60.0 else 0 end ) Dayreal,
	               sum(datediff(minute, 
	                            (case when io1 <= stdhour then stdhour else io1 end) ,
	                            (case when io2 <= out_time then io2 else out_time end)) / 60.0 - 
	                            case when ( breakbegin >= stdhour) then datediff(minute, breakbegin,breakend) / 60.0 else 0 end ) nightreal,
	               sum(case when (io1 <= stdhour and io2>= stdhour and datediff(hour, stdhour,io2) >= 4) then 1 else 0 end) nightnum	               
	          from uvw_ats_ioimport a
	         where a.att_date > = @begindate and 
	               a.att_date <= @enddate and 
	               a.shiftclassid = 'UFH Shift' and 
	               a.io1 <= stdhour and a.io2 >= stdhour and 
	              empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 

	--添加跨夜加班记一次夜班次数  
	update #Tmp
	   set nightnum = #Tmp.nightnum + a.nightnum       
	  from (select a.empid, 
		           sum(case when  (DATEDIFF(MINUTE,a.dayend,b.endtime)>0 and DATEDIFF(MINUTE,a.dayend,b.begintime)<0) then 1 else 0 end) nightnum	               
	          from uvw_ats_ioimport a inner join ats_empotsheet b on a.empid=b.empid
	         where a.att_date=b.att_date and
				   a.att_date > = @begindate and 
	               a.att_date <= @enddate and 
	               a.empid not in (select empid from emphr where punchrule = '*4' ) and b.flag=1
	      group by a.empid ) a
	 where #Tmp.empid = a.empid 


		/****** 法定处理 *****************/
	-- 需扣去已转为法定加班的时数 
	-- Day Shift 扣白班， Night Shift 扣夜班，UFH Shift - OT3从0点开始计，所以也肯定扣夜班（UFH Shift是从20：00开始计）
	update #Tmp
	   set Dayreal = Dayreal - a.OT3 
	from (select empid, sum(OT3) as OT3
	       from #ats_ioimport
	      where  shiftclassid = 'Day Shift' and 
	             att_date > = @begindate and att_date <= @enddate and 
	             empid not in (select empid from emphr where punchrule = '*4' )
	     group by empid) a
	 where #Tmp.empid = a.empid 
	
	--update #Tmp
	--   set nightreal =  nightreal - a.OT3
	--from (select empid, sum(OT3) as OT3
	--       from #ats_ioimport
	--      where  shiftclassid <> 'Day Shift' and 
	--			  att_date > = @begindate and att_date <= @enddate and 
	--             empid not in (select empid from emphr where punchrule = '*4' )
	--     group by empid) a
	-- where #Tmp.empid = a.empid 
	 update #Tmp
	   set nightreal =  nightreal - a.OT3
	from (select empid, sum(OT3) as OT3
	       from #ats_ioimport
	      where  shiftclassid = 'Night Shift' and 
				  att_date > = @begindate and att_date <= @enddate and 
	             empid not in (select empid from emphr where punchrule = '*4' )
	     group by empid) a
	 where #Tmp.empid = a.empid 

	 ----------------------------------------------------------------------
	 
	 	
	update #Tmp
		set Dayreal = Dayreal - a.OT3
	from (Select empid,att_date,sum(datediff(minute, in_time,stdhour) / 60.0 - 
						case when ( breakend <= stdhour) then datediff(minute, breakbegin,breakend) / 60.0 else 0 end)  as OT3
			 from uvw_ats_ioimport 
	         where att_date > =@begindate and 
	               att_date <= @enddate and 
	               shiftclassid = 'UFH Shift' and 
	               in_time <= stdhour and out_time >= stdhour and 
	               empid not in (select empid from emphr where punchrule = '*4' ) 
	      group by empid,att_date) a
	 where #Tmp.empid = a.empid 
	  and (a.att_date in (select holidaydate from holiday_d where daytype='H') )
	  
	  --夜班中从按时点班次扣除OT3,第二天是法定节假日的情况
	  update #Tmp
	   set  nightreal =  nightreal - a.OT3
	from (select empid,att_date,dayend, sum(datediff(minute, stdhour, out_time) / 60.0 - 
						case when ( breakbegin >= stdhour) then datediff(minute, breakbegin,breakend) / 60.0 else(DATEDIFF(MINUTE,stdhour,dayend)/60.0) end) as OT3
	          from uvw_ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               shiftclassid = 'UFH Shift' and 
	               in_time <= stdhour and out_time >= stdhour and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid,att_date,dayend ) a
	 where #Tmp.empid = a.empid 
	  and (a.att_date in (select holidaydate from holiday_d where daytype='H') and 
	   a.dayend in  (select holidaydate from holiday_d where daytype='H'))
	        
	   --夜班中从按时点班次扣除OT3,第二天不是法定节假日的情况
	  update #Tmp
	   set nightreal =  nightreal - a.OT3
	from (select empid,att_date,dayend, sum(datediff(minute, stdhour, out_time) / 60.0 - DATEDIFF(MINUTE,dayend,out_time)/60.0)as OT3
			 from uvw_ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               shiftclassid = 'UFH Shift' and 
	               in_time <= stdhour and out_time >= stdhour and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid,att_date,dayend ) a
	 where #Tmp.empid = a.empid 
	  and (a.att_date in (select holidaydate from holiday_d where daytype='H') and  
	  a.dayend not in  (select holidaydate from holiday_d where daytype='H'))      
	        
	 
	---- OT1 ------------------------------
	update #Tmp
	   set OT1 = round(a.OT1,2)	       
	  from (select empid, sum(otlength1) OT1	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               ottype1 = 'OT01' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
    
    --排班外
    update #Tmp
	   set OT1 = #Tmp.OT1 + a.OT1	       
	  from (select empid, sum(hours) OT1	               
	          from tbl_UnSchedule 
	         where dt > = @begindate and 
	               dt <= @enddate and 
	               ottype = 'OT01' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 

	--调休假结转
    update #Tmp	
	   set OT1 = #Tmp.OT1 + a.OT1  
	  from (select empid, sum(lvexchangetotal) OT1	               
	          from lvexchange_pay 
	         where attbegindate > = @begindate and 
	               attbegindate <= @enddate and 
	               Type = 'PAY' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 

    ---- OT2
	update #Tmp
	   set OT2 = round(a.OT2,2)	       
	  from (select empid, sum(otlength1) OT2	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               ottype1 = 'OT02' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
    
    --排班外
    update #Tmp
	   set OT2 = #Tmp.OT2 + a.OT2	       
	  from (select empid, sum(hours) OT2	               
	          from tbl_UnSchedule 
	         where dt > = @begindate and 
	               dt <= @enddate and 
	               ottype = 'OT02' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
	 
	---- OT3
	update #Tmp
	   set OT3 = round(a.OT3,2)	       
	  from (select empid, sum(otlength1) OT3	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               ottype1 = 'OT03' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
    
    --排班外
    update #Tmp
	   set OT3 = #Tmp.OT3 + a.OT3	       
	  from (select empid, sum(hours) OT3	               
	          from tbl_UnSchedule 
	         where dt > = @begindate and 
	               dt <= @enddate and 
	               ottype = 'OT03' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 

	/******* 法定处理 ***************/
	-- 要将排在法定的加班计入
	 update #Tmp
	   set OT3 = #Tmp.OT3 + a.OT3	       
	  from (select empid, sum(OT3) as OT3
	       from #ats_ioimport
	      where   att_date > = @begindate and att_date <= @enddate and 
	              empid not in (select empid from emphr where punchrule = '*4' )
	     group by empid ) a
	 where #Tmp.empid = a.empid 
	 

	---- OT4 - OTCom
	update #Tmp
	   set OTCom = round(a.OT4,2)	       
	  from (select empid, sum(otlength1) OT4	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               ottype1 = 'OT04' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
    
    --排班外
    update #Tmp
	   set OTCom = #Tmp.OTCom + a.OT4	       
	  from (select empid, sum(hours) OT4	               
	          from tbl_UnSchedule 
	         where dt > = @begindate and 
	               dt <= @enddate and 
	               ottype = 'OT04' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
	 
	----  OTCom Pay
	--调休假结转
    update #Tmp
	   set OTComPay = a.OT1	       
	  from (select empid, sum(lvexchangetotal) OT1	               
	          from lvexchange_pay 
	         where attbegindate > = @begindate and 
	               attbegindate <= @enddate and 
	               Type = 'PAY' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 ---- On Call --------------------------------------------
	 -- OnCallIn  float not null default(0)   ,--On Call (In house)   
	 -- OnCallHome	float not null default(0)   ,--On Call（Home）
	update #Tmp
	   set OnCallIn = a.OnCallIn	       
	  from (select empid, count(*) OnCallIn	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               oncall = 'In house' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
	 
	update #Tmp
	   set OnCallHome = a.OnCallHome	       
	  from (select empid, count(*) OnCallHome	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               oncall = 'Home' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 -----------------------------------------------------
	 /*
	 LV03	No Pay Sick Leave
	 LV14	Unpaid
	 nopaylv	float not null default(0)    ,--事假小时
	 sicklv	float not null default(0)     --病假小时
	 */
	 update #Tmp
	   set nopaylv = a.nopaylv	       
	  from (select empid, sum(leavetime1) nopaylv	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               leavetype1 = 'LV14' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 
	 update #Tmp
	   set nopaylv = #Tmp.nopaylv + a.nopaylv	       
	  from (select empid, sum(leavetime2) nopaylv	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               leavetype2 = 'LV14' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 
	 update #Tmp
	   set sicklv = a.sicklv	       
	  from (select empid, sum(leavetime1) sicklv	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               leavetype1 = 'LV03' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 update #Tmp
	   set sicklv = #Tmp.sicklv + a.sicklv	       
	  from (select empid, sum(leavetime2) sicklv	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               leavetype2 = 'LV03' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 
	 --带薪休假时数 
	 update #Tmp
	   set paidleave = a.paidleave	       
	  from (select empid, sum(leavetime1) paidleave	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               leavetype1 <> 'LV03' and leavetype1 <> 'LV14' and 
	              empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	 
	 update #Tmp
	   set paidleave = #Tmp.paidleave + a.paidleave	       
	  from (select empid, sum(leavetime2) paidleave	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               leavetype2 <> 'LV03' and leavetype2 <> 'LV14' and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid
	 
	-- 总计薪小时数
	 update #Tmp 
	 set totalhour = round(paidleave + Dayreal + nightreal,2),
	     status = case when ats_ioimport.postflag = 1 then 'Approved' else 'Approving' end 
	from ats_ioimport 
	where ats_ioimport.att_date > = @begindate and 
	      ats_ioimport.att_date <= @enddate and 
	      ats_ioimport.empid = #tmp.empid
	 


/**********************
Puch04 -- 统计白班:即标时-事假-病假、事假、病假、带薪假、OT3
***********************/
-- 病假
	update #Tmp 
	set sicklv = a.sicklv
	from (select empid, sum(leavetime)  sicklv
	        from ats_empleavesheet 
           where leavetype = 'LV03' and 
                 begintime >= @begindate and 
                 endtime <= @enddate and
                 empid in (select empid from emphr where punchrule = '*4' ) 
         group by empid) a
	where #Tmp.empid = a.empid
	
	-- 事假
	update #Tmp 
	set nopaylv = a.nopaylv
	from (select empid, sum(leavetime)  nopaylv
	        from ats_empleavesheet 
           where leavetype = 'LV14' and 
                 begintime >= @begindate and 
                 endtime <= @enddate and
                 empid in (select empid from emphr where punchrule = '*4' ) 
            group by empid) a
	where #Tmp.empid = a.empid
	
	-- 白班
	update #Tmp set Dayreal = stdwktime - sicklv - nopaylv, 
	                totalhour =  stdwktime - sicklv - nopaylv
	where empid in (select empid from emphr where punchrule = '*4' )

	-- OT3
	update #Tmp 
	set OT3 = a.OT3
	from (select empid, sum(ottime)  OT3
	        from ats_empotsheet 
           where OTtype = 'OT03' and 
                 begintime >= @begindate and 
                 begintime <= dateadd(day,1,@enddate) and
                 empid in (select empid from emphr where punchrule = '*4' ) 
            group by empid) a
	where #Tmp.empid = a.empid

/******************
返回结果
**********************/	 
	 -- wkgap = a.regwktime	- stdwktime    
	-- 当月入职或Puch04不计标时差
	-- 增加FTE = 0的，也不计标时差 20141014
	
	update #Tmp
	set OT3H = a.ot3
	from (select empid, sum(ot3) as ot3 from #ats_ioimport group by empid) a
	where #Tmp.empid = a.empid
	
	
	update #Tmp
	set tkempid = a.postby
	from (select distinct empid,postby from ats_ioimport where att_date > = @begindate and att_date <= @enddate)  a
	where #tmp.empid = a.empid
	
	update #Tmp
	set tkempcode = a.empcode, tkname = a.chinese
	from emphr a
	where #tmp.tkempid = a.empid
	
	-- 在考勤数据汇总界面，通过排班设置排的OT3，需要在计算差异时 从总的排班出来中间减出来 （这部分已经支付OT工资了，不能在累计调休假了）
	-- 差异 = 排班小时数 – 排班中的OT3时数 – 标准时数	 
	select #Tmp.empid , #Tmp.empcode,#Tmp.english,#Tmp.chinese,			
			round(regwktime,2) as regwktime,			-- 排班小时
			round(stdwktime, 2) stdwktime,				-- 标准小时
			case when ((emphr.hirevalid >= @begindate and emphr.hirevalid <= @enddate) or emphr.punchrule = '*4'  or emphr.fte = '0') then 0
			     else round(regwktime - stdwktime,2) end - OT3H as wkgap, -- 标时差
			round(paidleave,2) as paidleave,round(Dayreal,2) as Dayreal,
			round(nightreal,2) as nightreal,nightnum,round(OT1,2)as OT1,round(OT2,2)as OT2,round(OT3,2)as OT3,
			OTCom,OTComPay,OnCallIn,OnCallHome,round(nopaylv,1) as nopaylv,
			sicklv,
			round(worktime,2) as worktime,
			totalhour,status,
			tkempcode,tkname,OT3H,
			convert(nvarchar(10),emphr.hiredate,120) as hiredate,(h.emptype+'-'+i.chinese) as emptype,
emphr.orgcode1,(emphr.orgcode2+'-'+c.english) as orgcode2,(emphr.orgcode3+'-'+d.english) as orgcode3,(emphr.orgcode5+'-'+g.chinese)as orgcode5
	from #Tmp,emphr,organization c,organization d,emphr e,empself h,parameters i,organization g
where #Tmp.empid = emphr.empid 
and emphr.orgcode2=c.orgcode and emphr.orgcode3=d.orgcode and emphr.orgcode5=g.orgcode and h.serialnumber=emphr.serialnumber and h.emptype=i.paratype and emphr.timekeeper1=e.empcode
  and c.orglevel=2 and d.orglevel=3 and g.orglevel=5 and i.paracode='emptype'
  order by #Tmp.empcode collate Chinese_PRC_CS_AS_KS_WS
--select * from #ats_ioimport	where empid = 111397
--exec usp_ats_ReviewSum_rpt '','A782','2014-09-01','2014-09-30'

end



GO


