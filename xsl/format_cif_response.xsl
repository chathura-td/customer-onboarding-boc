<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>
  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="/IFX/CIFSvcRs/CustProfBasicInqRs/Status/StatusCode != '0'">
        <xsl:text>NOT_FOUND|</xsl:text>
        <xsl:value-of select="normalize-space(/IFX/CIFSvcRs/CustProfBasicInqRs/Status/Error/ErrNum)"/>
        <xsl:text>|</xsl:text>
        <xsl:value-of select="normalize-space(/IFX/CIFSvcRs/CustProfBasicInqRs/Status/Error/ErrDesc)"/>
      </xsl:when>
      <xsl:when test="/IFX/CIFSvcRs/CustProfBasicInqRs/Status/StatusCode = '0'">
        <xsl:text>SUCCESS|</xsl:text>
        <xsl:value-of select="normalize-space(/IFX/CIFSvcRs/CustProfBasicInqRs/CustProfBasic/BranchId)"/>
        <xsl:text>|</xsl:text>
        <xsl:value-of select="normalize-space(/IFX/CIFSvcRs/CustProfBasicInqRs/CustProfBasic/ShortName)"/>
        <xsl:text>|</xsl:text>
        <xsl:value-of select="normalize-space(/IFX/CIFSvcRs/CustProfBasicInqRs/CustProfBasic/CustStatusCode)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>ERROR|UNKNOWN_IFX_STRUCTURE</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>