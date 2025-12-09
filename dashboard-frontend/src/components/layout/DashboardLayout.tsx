import { ReactNode, useState } from 'react';
import { useAuth } from '../../hooks/useAuth';
import { useRouter } from 'next/router';
import { Icons } from '../ui/Icons';
import Button from '../ui/Button';

interface DashboardLayoutProps {
  children: ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const { user, logout } = useAuth();
  const router = useRouter();

  const handleLogout = () => {
    logout();
    router.push('/auth/login');
  };

  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  return (
    <div className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="bg-white border-b border-gray-200 sticky top-0 z-50 backdrop-blur-sm bg-white/95">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-black rounded-lg flex items-center justify-center">
                  <Icons.Container size={18} className="text-white" />
                </div>
                <h1 className="text-xl font-bold text-black">
                  Container Manager
                </h1>
              </div>
              {user && (
                <div className="ml-8 hidden md:flex items-center">
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 rounded-lg">
                    {user.role === 'admin' ? (
                      <Icons.Settings size={16} className="text-gray-600" />
                    ) : (
                      <Icons.User size={16} className="text-gray-600" />
                    )}
                    <span className="text-sm font-medium text-gray-700">
                      {user.role === 'admin' ? 'Administrator' : 'Client'}
                    </span>
                  </div>
                </div>
              )}
            </div>
            <div className="flex items-center gap-4">
              {user && (
                <>
                  <div className="hidden md:block text-right">
                    <div className="text-sm font-semibold text-black">{user.name}</div>
                    <div className="text-xs text-gray-500">{user.email}</div>
                  </div>
                  <Button
                    onClick={handleLogout}
                    variant="outline"
                    size="sm"
                    leftIcon={<Icons.LogOut size={16} />}
                    className="hidden md:flex"
                  >
                    Sign Out
                  </Button>
                  <button
                    onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                    className="md:hidden p-2 rounded-lg hover:bg-gray-100 transition-colors"
                  >
                    {isMobileMenuOpen ? (
                      <Icons.X size={20} />
                    ) : (
                      <Icons.Menu size={20} />
                    )}
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
        
        {/* Mobile menu */}
        {isMobileMenuOpen && user && (
          <div className="md:hidden border-t border-gray-200 bg-white">
            <div className="px-4 py-4 space-y-3">
              <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
                {user.role === 'admin' ? (
                  <Icons.Settings size={16} className="text-gray-600" />
                ) : (
                  <Icons.User size={16} className="text-gray-600" />
                )}
                <div>
                  <div className="text-sm font-semibold text-black">{user.name}</div>
                  <div className="text-xs text-gray-500">{user.role === 'admin' ? 'Administrator' : 'Client'}</div>
                </div>
              </div>
              <Button
                onClick={handleLogout}
                variant="outline"
                size="sm"
                leftIcon={<Icons.LogOut size={16} />}
                className="w-full justify-center"
              >
                Sign Out
              </Button>
            </div>
          </div>
        )}
      </nav>

      {/* Main content */}
      <main className="max-w-7xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
        {children}
      </main>

      {/* Footer */}
      <footer className="mt-auto bg-gray-50 border-t border-gray-200">
        <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <div className="flex items-center gap-2 text-sm text-gray-600">
              <Icons.Container size={16} />
              <span>Container Manager Platform</span>
            </div>
            <div className="text-xs text-gray-500 font-mono">
              v1.0.0
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}