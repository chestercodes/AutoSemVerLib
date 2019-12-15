# AutoSemVerLib

Repo showing automated versioning. 

Important files are:

- `versioning/AutoSemVer.ps1` - file that contains general functions.
- `BuildVersioning.ps1`  - file that contains lower level functions specific to project.
- `BuildAndPublish.ps1`  - high level script that builds and calls lower level functions.


## Library changes

`src/Lib.cs` changes in the following way.

``` csharp
namespace MyProject
{
    public class MyClass
    {
        public void MyMethod(string stringArg)
        {
        }
    }
}
```

An example of a minor change is the addition of a method.

``` csharp
namespace MyProject
{
    public class MyClass
    {
        public void MyMethod(string stringArg)
        {
        }
        
        public void MyMethod2(bool boolArg)
        {
        }
    }
}
```

An example of a major change is the change of argument of MyMethod to a bool.

``` csharp
namespace MyProject
{
    public class MyClass
    {
        public void MyMethod(bool boolArg)
        {
        }
    }
}
```



