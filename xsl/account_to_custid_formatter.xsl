<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <xsl:choose>

      <xsl:when test="/IFX/MaintSvcRs/AcctCustInqRs/Status/StatusCode != '0'">
        <xsl:text>ERROR|ACCT_LOOKUP_FAILED</xsl:text>
      </xsl:when>

      <xsl:when test="/IFX/MaintSvcRs/AcctCustInqRs/AcctRelation/CustPermId">
        <xsl:text>CUSTID|</xsl:text>
        <xsl:value-of select="normalize-space(/IFX/MaintSvcRs/AcctCustInqRs/AcctRelation/CustPermId)"/>
      </xsl:when>

      <xsl:otherwise>
        <xsl:text>ERROR|NO_RELATION_FOUND</xsl:text>
      </xsl:otherwise>

    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
