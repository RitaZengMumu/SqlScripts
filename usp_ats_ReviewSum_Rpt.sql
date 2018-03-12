/*
 ����Ա��ѯ�Լ����µ�Ա����ĳ�ڶ��ڵĿ��ڻ��ܣ��漰����ϵͳ������н��ϵͳ�������ݿ�
*/


CREATE  PROCEDURE [dbo].[usp_ats_ReviewSum_Rpt] 
	 @empcode		  nvarchar(50),  --��ĳ������Ա����
	 @currentusercode nvarchar(200), --��ǰԱ��(ϵͳ���ã�
	 @begindate       datetime,  --�ڶο�ʼ����
	 @enddate		  datetime   --�ڶν�������
AS
begin
	DECLARE @SQL nvarchar(500)
	
	 /**********************************************************************/   
	-- �����ʱ����ڣ���ɾ�� 
	if object_id('tempdb.dbo.#Tmp') is not null 
	begin
		drop table dbo.#Tmp
	end
	

	/************************************************************************/
	-- ����uvw_ats_ioimport, ���װ࣬ҹ�࣬OT3�Ȳ�ֺ�
	-- 1. �ȴ���ʼ����������Ƿ����յ�
	-- 2. �ٴ���ʼ����������Ƿ����յ�
	if object_id('tempdb.dbo.#ats_ioimport') is not null 
	begin
		drop table dbo.#ats_ioimport
	end

	select *,
		         -- �ڶ����Ƿ�����ȡ�ڶ���0�㿪ʼ�Ľ��� - �ݼ� - �м���Ϣ
	       case when isnull((select daytype from holiday_d where convert(nvarchar(10),in_time, 120) = holidaydate),'') <> 'H'  and 
	                 isnull((select daytype from holiday_d where convert(nvarchar(10),out_time, 120) = holidaydate),'') = 'H'  and
	                 (out_time > dayend and io2 > dayend)
							then round(datediff(minute, 
                                                case when (case when io1 > in_time then io1 else in_time end ) < dayend then dayend 
                                                     else (case when io1 > in_time then io1 else in_time end ) end,  -- ����ʱ����Ű�����ȡ����ʱ�䣻�ڿ����ȡ24��00
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
                                               (case when io1 > in_time then io1 else in_time end ),  -- ����ʱ����Ű�����ȡ����ʱ�䣻�ڿ����ȡ24��00
                                               case when (case when io2 > out_time then out_time else io2 end ) > dayend then dayend 
                                                     else (case when io2 > out_time then out_time else io2 end ) end  -- ����ʱ����Ű�����ȡ����ʱ�䣻�ڿ����ȡ24��00
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
	

	-- ������ʱ��
	create table #Tmp  --������ʱ��#Tmp
		(empid int not null default(0), 
		empcode nvarchar(50) not null default(''),
		english nvarchar(200) not null default(''),
		chinese nvarchar(200) not null default(''),
		regwktime float not null default(0),	--�Ű�Сʱ�� 
		stdwktime float not null default(0),	--��׼Сʱʱ
		wkgap     float not null default(0),	--����		
		Dayreal   float not null default(0),	--ʵ�ʰװ�
		paidleave	float not null default(0),	--��н�ݼ�Сʱ��
		nightreal float not null default(0),	--ʵ��ҹ��--------��ʵ���ϰ�Сʱ���� �������Ӱࣩ
		nightnum float not null default(0),	--ҹ�����
		OT1		float not null default(0),  --OT1
		OT2       float not null default(0)   ,--OT2
		OT3       float not null default(0)   ,--OT3
		OTCom     float not null default(0)   ,--OT Com
		OTComPay  float not null default(0)  ,--OT Com Pay
		OnCallIn  float not null default(0)   ,--On Call (In house)   
		OnCallHome	float not null default(0)   ,--On Call��Home��
		nopaylv	float not null default(0)    ,--�¼�Сʱ
		sicklv	float not null default(0),     --����Сʱ
		worktime float not null default(0), ---ʵ�ʹ���Сʱ
		totalhour float not null default(0), -- �ܼ�нСʱ�� ��ʵ�ʰװ�+��н�ݼ�+ʵ��ҹ�ࣩ
		status nvarchar(50) not null default(''), ---����Ա�ύ״̬
		tkempid int not null default(0),
		tkempcode nvarchar(50) not null default(''),
		tkname nvarchar(50) not null default(''),
		OT3H	float not null default(0)			--�Ű��ڷ�����OT3
       )
    
     /**********************************************************************/ 
     -- ȷ��չʾ��Ա����Χ
 --   if @empcode <> 0
	--	begin
	--		-- ��ѯ����Ա��
	--		insert into #Tmp(empid,empcode,english,chinese)
	--			(select empid,empcode,english,chinese
	--			   from emphr 
	--			  where empcode like @empcode or chinese like @empcode or english like @empcode )
	--	end
	--else
	--	begin
					
			-- ��ѯ����Ա������Ա����ǿ���Ա����ѯ����
			declare @timekeeper int
			declare @UserID int
			declare @Filter nvarchar(50)
			--declare @count int
			
			-- ȡ����Ա��empid
			select @timekeeper = empid 
			  from emphr 
			 where empcode = @empcode or chinese = @empcode or english = @empcode
			 
			-- ȡ��ǰ�û���Ա������
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
					-- �ǿ���Ա������HR, ��������Ա�����ˣ�
					set @SQL = ' insert into #Tmp(empid,empcode,english,chinese) ' + 
						       ' (select empid,empcode,english,chinese ' +
						       ' from emphr ' +
						       ' where empid in (select empid from [StrategyDBCompany_' + @Filter + ']))'
				     exec sp_executesql @SQL 
				     --print @sql
				end
			else
				-- ����Ա
				begin
					insert into #Tmp(empid,empcode,english,chinese)
						(select empid,empcode,english,chinese
						   from emphr 
						  where (timekeeper=@userid or timekeeperid2 = @userid or timekeepadmin = @userid) and 
						        empid in (select empid from [StrategyDBCompany_All_Active_Employees]))
				end
			
		--end
 
    /******************************************************************
     ͳ�����ָ��
    ***************/  
    

	-- ��׼Сʱ��
	update #Tmp
	   set stdwktime = a.stanhours
	  from payperiod a
	 where a.attbegindate = @begindate

	--update #Tmp
	--   set stdwktime = stdwktime * emphr.fte
	--  from emphr 
	-- where #Tmp.empid = emphr.empid
	
	--2015/11/27�鿴FTE�ı䶯ʱ��
     update #Tmp
	    set stdwktime = stdwktime * (CASE WHEN emphr.fte_date<@enddate or emphr.fte_date is null THEN  emphr.fte ELSE ess_anlvyear.FTEhis end)
	  from emphr,ess_anlvyear
	 where #Tmp.empid = emphr.empid AND #Tmp.empid=ess_anlvyear.empid AND ess_anlvyear.curflag=1
	
	---- �Ű�Сʱ��/�Ű�ʱ��
	update #Tmp
	   set regwktime = a.regwktime      
	  from (select empid, sum(regwktime) regwktime	               
	          from ats_ioimport 
	         where att_date > = @begindate and 
	               att_date <= @enddate and 
	               empid not in (select empid from emphr where punchrule = '*4' )
	      group by empid ) a
	 where #Tmp.empid = a.empid 
	
	---- ʵ���ϰ�Сʱ
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
	ʵ���ϰ�İװ�ʱ��[Day Shift]��ҹ��ʱ��[Night Shift],��8����[UFH Shift]
	shiftclassid,workhourid, worktime
	***********************************************/
	-- �װ�
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

	-- ҹ��
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


	-- ��8���ֵİ�ҹ��(�������Ű࿪ʼʱ�������Ϊ׼���뿪���Ű����ʱ�������Ϊ׼��
	-- ����ˡ���8����ϰ�4Сʱ��1��ҹ�ࡱ
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

	--��ӿ�ҹ�Ӱ��һ��ҹ�����  
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


		/****** �������� *****************/
	-- ���ȥ��תΪ�����Ӱ��ʱ�� 
	-- Day Shift �۰װ࣬ Night Shift ��ҹ�࣬UFH Shift - OT3��0�㿪ʼ�ƣ�����Ҳ�϶���ҹ�ࣨUFH Shift�Ǵ�20��00��ʼ�ƣ�
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
	  
	  --ҹ���дӰ�ʱ���ο۳�OT3,�ڶ����Ƿ����ڼ��յ����
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
	        
	   --ҹ���дӰ�ʱ���ο۳�OT3,�ڶ��첻�Ƿ����ڼ��յ����
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
    
    --�Ű���
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

	--���ݼٽ�ת
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
    
    --�Ű���
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
    
    --�Ű���
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

	/******* �������� ***************/
	-- Ҫ�����ڷ����ļӰ����
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
    
    --�Ű���
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
	--���ݼٽ�ת
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
	 -- OnCallHome	float not null default(0)   ,--On Call��Home��
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
	 nopaylv	float not null default(0)    ,--�¼�Сʱ
	 sicklv	float not null default(0)     --����Сʱ
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
	 
	 
	 --��н�ݼ�ʱ�� 
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
	 
	-- �ܼ�нСʱ��
	 update #Tmp 
	 set totalhour = round(paidleave + Dayreal + nightreal,2),
	     status = case when ats_ioimport.postflag = 1 then 'Approved' else 'Approving' end 
	from ats_ioimport 
	where ats_ioimport.att_date > = @begindate and 
	      ats_ioimport.att_date <= @enddate and 
	      ats_ioimport.empid = #tmp.empid
	 


/**********************
Puch04 -- ͳ�ưװ�:����ʱ-�¼�-���١��¼١����١���н�١�OT3
***********************/
-- ����
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
	
	-- �¼�
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
	
	-- �װ�
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
���ؽ��
**********************/	 
	 -- wkgap = a.regwktime	- stdwktime    
	-- ������ְ��Puch04���Ʊ�ʱ��
	-- ����FTE = 0�ģ�Ҳ���Ʊ�ʱ�� 20141014
	
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
	
	-- �ڿ������ݻ��ܽ��棬ͨ���Ű������ŵ�OT3����Ҫ�ڼ������ʱ ���ܵ��Ű�����м������ ���ⲿ���Ѿ�֧��OT�����ˣ��������ۼƵ��ݼ��ˣ�
	-- ���� = �Ű�Сʱ�� �C �Ű��е�OT3ʱ�� �C ��׼ʱ��	 
	select #Tmp.empid , #Tmp.empcode,#Tmp.english,#Tmp.chinese,			
			round(regwktime,2) as regwktime,			-- �Ű�Сʱ
			round(stdwktime, 2) stdwktime,				-- ��׼Сʱ
			case when ((emphr.hirevalid >= @begindate and emphr.hirevalid <= @enddate) or emphr.punchrule = '*4'  or emphr.fte = '0') then 0
			     else round(regwktime - stdwktime,2) end - OT3H as wkgap, -- ��ʱ��
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


