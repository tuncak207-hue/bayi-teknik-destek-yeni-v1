import { AuthController } from '../auth.controller';

describe('AuthController cookie session contract', () => {
  const tokens = { accessToken: 'access-token', refreshToken: 'refresh-token' };
  const authService = {
    login: jest.fn(),
    refresh: jest.fn(),
  };
  const jwt = { verify: jest.fn() };
  const response = {
    cookie: jest.fn(),
    clearCookie: jest.fn(),
  };
  let controller: AuthController;

  beforeEach(() => {
    jest.clearAllMocks();
    controller = new AuthController(authService as any, jwt as any);
  });

  it('issues HttpOnly access and refresh cookies at login', async () => {
    authService.login.mockResolvedValue(tokens);

    await controller.login({ email: 'admin@example.com', password: 'test' } as any, response as any);

    expect(response.cookie).toHaveBeenCalledTimes(2);
    expect(response.cookie.mock.calls[0][0]).toBe('admin_access_token');
    expect(response.cookie.mock.calls[0][1]).toBe(tokens.accessToken);
    expect(response.cookie.mock.calls[0][2]).toEqual(expect.objectContaining({ httpOnly: true }));
    expect(response.cookie.mock.calls[1][0]).toBe('admin_refresh_token');
  });

  it('refreshes from the refresh cookie without requiring the access cookie', async () => {
    jwt.verify.mockReturnValue({ sub: 'admin-id' });
    authService.refresh.mockResolvedValue(tokens);
    const request = { headers: { cookie: 'admin_refresh_token=refresh-token' } };

    await controller.refresh(request as any, response as any);

    expect(jwt.verify).toHaveBeenCalledWith('refresh-token');
    expect(authService.refresh).toHaveBeenCalledWith('admin-id');
    expect(response.cookie).toHaveBeenCalledTimes(2);
  });

  it('clears both cookies on logout', () => {
    controller.logout(response as any);

    expect(response.clearCookie).toHaveBeenCalledWith('admin_access_token', expect.any(Object));
    expect(response.clearCookie).toHaveBeenCalledWith('admin_refresh_token', expect.any(Object));
  });
});
