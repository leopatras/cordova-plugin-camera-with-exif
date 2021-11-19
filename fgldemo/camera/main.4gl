IMPORT util
IMPORT FGL fgldialog

CONSTANT quality=100
CONSTANT DestinationTypeDataUrl = 0
CONSTANT DestinationTypeFileUri = 1
CONSTANT DestinationTypeNativeUri = 2

CONSTANT PictureSourceTypePhotoLibrary= 0 -- Choose image from the device's photo library (same as SAVEDPHOTOALBUM for Android) 
CONSTANT PictureSourceTypeCamera= 1 -- Take picture from camera
CONSTANT PictureSourceTypeSavedPhotoAlbum= 2 -- Choose image only from the device's Camera Roll album (same as PHOTOLIBRARY for Android)

CONSTANT  EncodingTypeJPEG=0 --Return JPEG encoded image
CONSTANT  EncodingTypePNG=1 --Return PNG encoded image

CONSTANT  MediaTypePicture=0 --Allow selection of still pictures only. DEFAULT. Will return format specified via DestinationType
CONSTANT  MediaTypeVideo=1 --Allow selection of video only, ONLY RETURNS URL */
CONSTANT  MediaTypeAll=2 --Allow selection from all media types

CONSTANT allowsEditing=FALSE
CONSTANT correctOrientation=TRUE
CONSTANT saveToPhotoAlbum=TRUE

CONSTANT PopoverArrowDirectionUp=1
CONSTANT PopoverArrowDirectionDown=2
CONSTANT PopoverArrowDirectionLeft=4
CONSTANT PopoverArrowDirectionRight=8
CONSTANT PopoverArrowDirectionAny=15

DEFINE popoverOptions RECORD 
  x INT,
  y INT,
  width INT,
  height INT,
  arrowDir INT
END RECORD

DEFINE resultset RECORD
  filename STRING,
  json_metadata STRING
END RECORD

DEFINE exif RECORD
    GPS RECORD
        Latitude FLOAT,
        ImgDirection FLOAT,
        --GPSVersion DYNAMIC ARRAY OF FLOAT,
        Altitude FLOAT,
        Longitude FLOAT,
        SpeedRef STRING,
        Speed FLOAT,
        LongitudeRef STRING,
        LatitudeRef STRING,
        ImgDirectionRef STRING,
        MapDatum STRING
    END RECORD,
    Exif RECORD
        --ExifVersion DYNAMIC ARRAY OF FLOAT,
        Contrast FLOAT,
        LightSource FLOAT,
        Flash FLOAT,
        SubsecTimeOriginal STRING,
        ExposureMode FLOAT,
        Saturation FLOAT,
        FNumber FLOAT,
        FileSource FLOAT,
        PixelYDimension FLOAT,
        Sharpness FLOAT,
        ApertureValue FLOAT,
        FocalPlaneXResolution FLOAT,
        MeteringMode FLOAT,
        FocalPlaneResolutionUnit FLOAT,
        --ISOSpeedRatings DYNAMIC ARRAY OF FLOAT,
        ExposureBiasValue FLOAT,
        ShutterSpeedValue FLOAT,
        SceneCaptureType FLOAT,
        MaxApertureValue FLOAT,
        CustomRendered FLOAT,
        GainControl FLOAT,
        SubjectDistRange FLOAT,
        FocalLength FLOAT,
        FocalPlaneYResolution FLOAT,
        DateTimeOriginal STRING,
        --FlashPixVersion DYNAMIC ARRAY OF FLOAT,
        ColorSpace FLOAT,
        PixelXDimension FLOAT,
        SensingMethod FLOAT,
        FocalLenIn35mmFilm FLOAT,
        DigitalZoomRatio FLOAT,
        SubsecTimeDigitized STRING,
        DateTimeDigitized STRING,
        --ComponentsConfiguration DYNAMIC ARRAY OF FLOAT,
        WhiteBalance FLOAT,
        ExposureTime FLOAT,
        ExposureProgram FLOAT
    END RECORD,
    TIFF RECORD
        Artist STRING,
        ResolutionUnit FLOAT,
        Software STRING,
        Model STRING,
        DateTime STRING,
        XResolution FLOAT,
        Orientation FLOAT,
        YResolution FLOAT,
        Copyright STRING,
        Make STRING
    END RECORD
END RECORD



CONSTANT  CameraDirectionBack=0 -- Use the back-facing camera
CONSTANT  CameraDirectionFront=1 -- Use the front-facing camera


MAIN
    DEFINE result STRING
    DEFINE targetWidth , targetHeight INT
    LET targetHeight=500
    LET targetWidth=500
    --OPEN FORM f FROM "main"
    --DISPLAY FORM f

    CALL ui.Interface.frontCall("cordova","settings",["set","CameraUsesGeolocation","true"],[])
    LET popoverOptions.x=0;
    LET popoverOptions.y=0;
    LET popoverOptions.width=400;
    LET popoverOptions.height=400;
    LET popoverOptions.arrowDir=PopoverArrowDirectionDown

    MENU "Camera"
      COMMAND "Choose Picture"
        TRY
          CALL ui.Interface.frontCall("cordova","call",
          ["Camera","takePicture",
           quality,DestinationTypeFileUri,PictureSourceTypePhotoLibrary,
            targetWidth,targetHeight,EncodingTypeJPEG,MediaTypeAll,
            allowsEditing,correctOrientation,saveToPhotoAlbum,
            popoverOptions,CameraDirectionBack],[resultset])
          --CALL writeToResults(resultset.filename)
          --ERROR resultset.filename,"width:",exif.Exif.PixelXDimension,",height:",exif.Exif.PixelYDimension
          --ERROR result
          CALL displayPhoto()
        CATCH 
          ERROR err_get(status)
        END TRY
      COMMAND "Take Picture"
        TRY
          CALL ui.Interface.frontCall("cordova","call",
          ["Camera","takePicture",
           quality,DestinationTypeFileUri,PictureSourceTypeCamera,
            targetWidth,targetHeight,EncodingTypeJPEG,MediaTypeAll,
            allowsEditing,correctOrientation,saveToPhotoAlbum,
            popoverOptions,CameraDirectionBack],[resultset])
          CALL displayPhoto()
        CATCH 
          ERROR err_get(status)
        END TRY
    END MENU
END MAIN

FUNCTION writeToResults(result STRING)
  DEFINE ch base.Channel
  LET ch=base.Channel.create()
  TRY
      CALL ch.openFile("/tmp/result.txt","w")
      CALL ch.writeLine(result)
      CALL ch.close()
  END TRY
END FUNCTION


FUNCTION displayPhoto()
  DEFINE whs STRING
  LET resultset.json_metadata=replace_char(resultset.json_metadata,
                                                   '"{TIFF}"','"TIFF"')
  INITIALIZE exif.* TO NULL
  CALL fgl_winmessage("2",resultset.json_metadata,"ok")
  CALL util.JSON.parse(resultset.json_metadata,exif)
  OPEN WINDOW viewer WITH FORM "main"
  DISPLAY resultset.filename TO photo
  --ERROR "result:",result
  MENU
    BEFORE MENU
      CALL DIALOG.setActionHidden("location",1)
      CALL DIALOG.setActionHidden("info",1)
      IF exif.GPS.Latitude IS NOT NULL AND exif.GPS.Latitude<>0 AND
         exif.GPS.Longitude IS NOT NULL AND exif.GPS.Longitude<>0 THEN
         CALL DIALOG.setActionHidden("location",0)
      END IF
      IF ui.Interface.getFrontEndName()=="GMI" THEN
        CALL DIALOG.setActionHidden("info",0)
      END IF
    ON ACTION info ATTRIBUTE(TEXT="Info")
      CALL ui.Interface.frontCall("qa","getAttribute",
                              ["objectName","viewer_FormField_photo",
                               "imageSizeAndScaleOfImage"],[whs])
      MESSAGE "Width x Height @scale:",whs
    ON ACTION location ATTRIBUTE(TEXT="Location")
      CALL showLocation()
    ON ACTION close
      EXIT MENU
  END MENU
  CLOSE WINDOW viewer
END FUNCTION

FUNCTION showLocation()
  DEFINE mystatus STRING
  DEFINE latitude,longitude FLOAT
  LET latitude=exif.GPS.Latitude
  LET longitude=exif.GPS.Longitude
  ERROR SFMT("Geo location: Latitude=%2 Longitude=%3",mystatus, latitude, longitude )
  CALL ui.Interface.frontCall("standard", "launchurl",
      ["http://maps.apple.com/?ll="||get_geolocation_str(latitude,longitude)||"&z=17&q=Here"], [])
END FUNCTION

FUNCTION get_geolocation_str(latitude,longitude)
  DEFINE latitude,longitude FLOAT
  --due to internationalization on the phone we need to ensure that we have a "."
  --in the formatting
  RETURN SFMT("%1,%2",util.JSON.stringify(latitude),util.JSON.stringify(longitude))
END FUNCTION

FUNCTION replace_char(str, chartofind , replacechar)
  DEFINE str,chartofind,replacechar STRING
  DEFINE buf base.StringBuffer
  LET buf=base.StringBuffer.create()
  CALL buf.append(str)
  CALL buf.replace(chartofind,replacechar,0)
  RETURN buf.toString()
END FUNCTION
