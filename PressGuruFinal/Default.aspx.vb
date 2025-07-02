Imports System.Web.Services, System.Configuration, System.Data.SqlClient, System.Threading.Tasks, System.Net.Http, System.Text, System.Net, Newtonsoft.Json, System.IO

Public Class _Default
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12
    End Sub
End Class

