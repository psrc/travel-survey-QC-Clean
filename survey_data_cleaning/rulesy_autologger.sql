/* auto-logging trigger for hhts_cleaning.HHSurvey.Trip */

CREATE PROCEDURE rulesy_audit_trigger
AS
BEGIN

  SET NOCOUNT ON;

--Remove any audit trail records that may already exist from previous runs of Rulesy.
    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS HHSurvey.tblTripAudit;
    DROP TRIGGER IF EXISTS HHSurvey.tr_trip;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    CREATE TABLE [HHSurvey].[tblTripAudit](
    [Type] [char](1) NULL,
    [recid] [bigint] NOT NULL,
    [FieldName] [varchar](128) NULL,
    [OldValue] [nvarchar](max) NULL,
    [NewValue] [nvarchar](max) NULL,
    [UpdateDate] [datetime] NULL,
    [UserName] [varchar](128) NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];
    COMMIT TRANSACTION;

-- create an auto-logging trigger for updates to the trip table
    BEGIN TRANSACTION;
    SET QUOTED_IDENTIFIER OFF;
    COMMIT TRANSACTION;
    BEGIN TRANSACTION;
    DECLARE @TriggerCode NVARCHAR(max);

    SET @TriggerCode = "
		DROP TRIGGER IF EXISTS HHSurvey.tr_trip;
		GO
		create  trigger tr_trip on HHSurvey.[trip] for insert, update, delete
		as

		declare @bit int ,
		    @field int ,
		    @maxfield int ,
		    @char int ,
		    @fieldname varchar(128) ,
		    @TableName varchar(128) ,
			@SchemaName varchar(128),
		    @PKCols varchar(1000) ,
		    @sql varchar(2000), 
		    @UpdateDate varchar(21) ,
		    @UserName varchar(128) ,
		    @Type char(1) ,
		    @PKSelect varchar(1000)
		    
		    select @TableName = 'trip'
			select @SchemaName = 'HHSurvey'

		    -- date and user
		    select  @UserName = system_user ,
		        @UpdateDate = convert(varchar(8), getdate(), 112) + ' ' + convert(varchar(12), getdate(), 114)

		    -- Action
		    if exists (select * from inserted)
		        if exists (select * from deleted)
		            select @Type = 'U'
		        else
		            select @Type = 'I'
		    else
		        select @Type = 'D'
		    
		    -- get list of columns
		    select * into #ins from inserted
		    select * into #del from deleted
		    
		    -- Get primary key columns for full outer join
		    select  @PKCols = coalesce(@PKCols + ' and', ' on') + ' i.[' + c.COLUMN_NAME + '] = d.[' + c.COLUMN_NAME + ']'
		    from    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
		        INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
		    where   pk.TABLE_NAME = @TableName
		    and CONSTRAINT_TYPE = 'PRIMARY KEY'
		    and c.TABLE_NAME = pk.TABLE_NAME
		    and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
		    
		    -- Get primary key select for insert.  @PKSelect will contain the recid info defining the precise line
		    -- in trips that is edited.  This variable is formatted to be used as part of the SELECT clause in the query 
		    -- (below) that inserts the data into.
		    select  @PKSelect = coalesce(@PKSelect+',','') + 'convert(varchar(100),coalesce(i.[' + COLUMN_NAME +'],d.[' + COLUMN_NAME + ']))' 
		        from    INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
		            INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
		        where   pk.TABLE_NAME = @TableName
				and pk.TABLE_SCHEMA = @SchemaName
				AND c.TABLE_SCHEMA = @SchemaName
		        and CONSTRAINT_TYPE = 'PRIMARY KEY'
		        and c.TABLE_NAME = pk.TABLE_NAME
		        and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME
		        ORDER BY c.ORDINAL_POSITION

		    if @PKCols is null
		    begin
		        raiserror('no PK on table %s', 16, -1, @TableName)
		        return
		    end

		    select @field = 0, @maxfield = max(ORDINAL_POSITION) 
			from INFORMATION_SCHEMA.COLUMNS 
			where TABLE_NAME = @TableName 
				and TABLE_SCHEMA = @SchemaName

		    while @field < @maxfield
		    begin
		        select @field = min(ORDINAL_POSITION) 
				from INFORMATION_SCHEMA.COLUMNS 
				where TABLE_NAME = @TableName 
					and ORDINAL_POSITION > @field 
					and TABLE_SCHEMA = @SchemaName
					and data_type NOT IN('geography','geometry')

		        select @bit = (@field - 1 )% 8 + 1

		        select @bit = power(2,@bit - 1)

		        select @char = ((@field - 1) / 8) + 1

		        if ( substring(COLUMNS_UPDATED(),@char, 1) & @bit > 0 or @Type in ('I','D') )
		        begin
		            select @fieldname = COLUMN_NAME 
					from INFORMATION_SCHEMA.COLUMNS 
					where TABLE_NAME = @TableName 
						and ORDINAL_POSITION = @field 
						and TABLE_SCHEMA = @SchemaName

		            begin
		                select @sql =       'insert into HHSurvey.tblTripAudit (Type, recid, FieldName, OldValue, NewValue, UpdateDate, UserName)'
		                select @sql = @sql +    ' select ''' + @Type + ''''
		                select @sql = @sql +    ',' + @PKSelect
		                select @sql = @sql +    ',''' + @fieldname + ''''
		                select @sql = @sql +    ',convert(varchar(max),d.[' + @fieldname + '])'
		                select @sql = @sql +    ',convert(varchar(max),i.[' + @fieldname + '])'
		                select @sql = @sql +    ',''' + @UpdateDate + ''''
		                select @sql = @sql +    ',''' + @UserName + ''''
		                select @sql = @sql +    ' from #ins i full outer join #del d'
		                select @sql = @sql +    @PKCols
		                select @sql = @sql +    ' where i.[' + @fieldname + '] <> d.[' + @fieldname + ']'
		                select @sql = @sql +    ' or (i.[' + @fieldname + '] is null and  d.[' + @fieldname + '] is not null)' 
		                select @sql = @sql +    ' or (i.[' + @fieldname + '] is not null and  d.[' + @fieldname + '] is null)' 
		                exec (@sql)
		            end
		        end
		    end
		GO"

    SET QUOTED_IDENTIFIER ON;
    EXEC(@TriggerCode);
    COMMIT TRANSACTION;
    
    ALTER TABLE HHSurvey.Trip DISABLE TRIGGER tr_trip;
END
