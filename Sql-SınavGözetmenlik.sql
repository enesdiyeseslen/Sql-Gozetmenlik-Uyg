CREATE PROCEDURE dbo.Sp_FinalSinavi 
AS
BEGIN

BEGIN TRY 
	BEGIN TRANSACTION FinalSinavi  -- tabloda tüm işlemler başarılı olursa işleme almak için
  SET NOCOUNT ON;-- sql den etkilenen satırları saymaması için


-- Her şeyden önce   Kontenjanlar, SinavBinalari, SinavSalonlari tablolarını temizleyelim
DELETE FROM FinalSinavi.dbo.Kontenjanlar where 1=1;
DELETE FROM FinalSinavi.dbo.SinavBinalari where 1=1;
DELETE FROM FinalSinavi.dbo.SinavSalonlari where 1=1;

-- 1. aşamayı yapıyoruz
DECLARE @BinaID INT

DECLARE BinaGuncellemeOku CURSOR FOR
SELECT BinaID	FROM FinalSinavi.dbo.Binalar;

OPEN BinaGuncellemeOku
FETCH NEXT FROM BinaGuncellemeOku INTO @BinaID
WHILE @@FETCH_STATUS = 0 BEGIN

  DECLARE @BinaKapasiteBul INT= 0;
  SELECT @BinaKapasiteBul = sum(Kapasite) FROM FinalSinavi.dbo.Salonlar WHERE BinaID = @BinaID;
  UPDATE FinalSinavi.dbo.Binalar SET Kapasite = @BinaKapasiteBul WHERE BinaID=@BinaID;

	FETCH NEXT FROM BinaGuncellemeOku INTO @BinaID
END

CLOSE BinaGuncellemeOku
DEALLOCATE BinaGuncellemeOku

-- 2. aşamayı yapıyoruz
DECLARE @ToplamOgrenci INT =0;
SELECT @ToplamOgrenci = sum(ÖğrenciSayısı) FROM FinalSinavi.dbo.OgrenciSayilari;

DECLARE @BinaIDParametre INT,@SınavMerkeziParametre VARCHAR(50),@BinaAdıParametre VARCHAR(50)
,@BinaAdresParametre VARCHAR(100),@SalonSayisiParametre INT,@KapasiteParametre INT;

DECLARE @AraDegisken INT = @ToplamOgrenci;

DECLARE SinavBinaOku CURSOR FOR
SELECT BinaID ,SınavMerkezi ,BinaAdı ,BinaAdres ,SalonSayisi ,Kapasite
FROM dbo.Binalar order BY Kapasite desc

OPEN SinavBinaOku
FETCH NEXT FROM SinavBinaOku INTO @BinaIDParametre ,@SınavMerkeziParametre ,@BinaAdıParametre ,@BinaAdresParametre ,@SalonSayisiParametre ,@KapasiteParametre ;
WHILE @@FETCH_STATUS = 0 BEGIN

SET @AraDegisken = @AraDegisken - @KapasiteParametre;
            
            INSERT INTO dbo.SinavBinalari
            (BinaID,SınavMerkezi,BinaAdı,BinaAdres,SalonSayisi,Kapasite) VALUES(@BinaIDParametre,@SınavMerkeziParametre,@BinaAdıParametre,@BinaAdresParametre,@SalonSayisiParametre,CASE WHEN @AraDegisken < 0 THEN @KapasiteParametre + @AraDegisken ELSE @KapasiteParametre END );

IF @AraDegisken < 0 BEGIN  
	BREAK;
END


FETCH NEXT FROM SinavBinaOku INTO @BinaIDParametre ,@SınavMerkeziParametre ,@BinaAdıParametre ,@BinaAdresParametre ,@SalonSayisiParametre ,@KapasiteParametre ;
END
CLOSE SinavBinaOku
DEALLOCATE SinavBinaOku



-- 3. aşamayı yapıyoruz
TRUNCATE TABLE dbo.SinavSalonlari;

DECLARE @SalonID_Oku INT,
        @SalonAdı_Oku VARCHAR(50),
        @BulunduğuKat_Oku TINYINT;
SET @AraDegisken = @ToplamOgrenci;

DECLARE SinavSalonlariniOku CURSOR FOR
SELECT 
DISTINCT sl.SalonID,sl.BinaID,sl.SalonAdı,sl.BulunduğuKat,sl.Kapasite
FROM FinalSinavi.dbo.Salonlar sl, FinalSinavi.dbo.SinavBinalari sb
  WHERE sl.BinaId = sb.BinaId
  


OPEN SinavSalonlariniOku

FETCH NEXT FROM SinavSalonlariniOku INTO @SalonID_Oku,@BinaIDParametre ,@SalonAdı_Oku ,@BulunduğuKat_Oku ,@KapasiteParametre ;

WHILE @@FETCH_STATUS = 0 BEGIN

SET @AraDegisken = @AraDegisken - @KapasiteParametre;
        -- burada SinavSalonlari dolduruyoruz
        INSERT INTO dbo.SinavSalonlari (SalonID,BinaID,SalonAdı,BulunduğuKat,Kapasite) VALUES(@SalonID_Oku,@BinaIDParametre,@SalonAdı_Oku,@BulunduğuKat_Oku,CASE WHEN @AraDegisken < 0 THEN @KapasiteParametre + @AraDegisken ELSE @KapasiteParametre END );

IF @AraDegisken < 0 BEGIN  
	BREAK;
END


FETCH NEXT FROM SinavSalonlariniOku INTO @SalonID_Oku,@BinaIDParametre ,@SalonAdı_Oku ,@BulunduğuKat_Oku ,@KapasiteParametre ;

END

CLOSE SinavSalonlariniOku
DEALLOCATE SinavSalonlariniOku


-- 4. aşamayı yapıyoruz
INSERT INTO dbo.Kontenjanlar(GorevAdı,BinaID,SalonID)
SELECT 'Bina Sınav Sorumlusu', BinaId, NULL FROM FinalSinavi.dbo.SinavBinalari

DECLARE @counter INT = 1;  

DECLARE SalonGorevlileriAtamaOkuma CURSOR FOR
SELECT 
SalonID
  ,BinaID
      ,Kapasite 
FROM FinalSinavi.dbo.SinavSalonlari ORDER BY Kapasite desc

OPEN SalonGorevlileriAtamaOkuma

FETCH NEXT FROM SalonGorevlileriAtamaOkuma INTO @SalonID_Oku,@BinaIDParametre,@KapasiteParametre

WHILE @@FETCH_STATUS = 0 BEGIN
-- burada salon başkanlarını dolduruyoruz
INSERT INTO dbo.Kontenjanlar(GorevAdı,BinaID,SalonID) VALUES('SALON BAŞKANI', @BinaIDParametre, @SalonID_Oku )

  IF @KapasiteParametre BETWEEN 0 AND 30 BEGIN  
    SET @counter = 1;
  END
  ELSE IF @KapasiteParametre BETWEEN 31 AND 50 BEGIN  
  	SET @counter = 2;
  END
  ELSE IF @KapasiteParametre BETWEEN 51 AND 70 BEGIN  
    	SET @counter = 3;
  END
    ELSE IF @KapasiteParametre BETWEEN 71 AND 90 BEGIN  
    	SET @counter = 4;
  END
	  
      DECLARE @adetSay INT = 1;
      WHILE @adetSay <= @counter
      BEGIN
        -- burada gözetmenleri dolduruyoruz
        INSERT INTO dbo.Kontenjanlar(GorevAdı,BinaID,SalonID) VALUES('GÖZETMEN', @BinaIDParametre, @SalonID_Oku );
        SET @adetSay = @adetSay + 1;
      END;


	FETCH NEXT FROM SalonGorevlileriAtamaOkuma INTO @SalonID_Oku,@BinaIDParametre,@KapasiteParametre

END

CLOSE SalonGorevlileriAtamaOkuma
DEALLOCATE SalonGorevlileriAtamaOkuma




  COMMIT TRAN FinalSinavi;
END TRY
BEGIN CATCH
  IF @@trancount > 0 
  ROLLBACK TRAN FinalSinavi;
  THROW 
END CATCH

END
GO