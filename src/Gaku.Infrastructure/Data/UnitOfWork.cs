using Gaku.Core.Interfaces;

namespace Gaku.Infrastructure.Data;

// GakuDbContext doubles as IUnitOfWork to avoid an extra wrapper type.
public partial class GakuDbContext : IUnitOfWork { }
